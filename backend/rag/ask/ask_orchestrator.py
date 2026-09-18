import traceback
from datetime import datetime
from typing import List, Optional

from google.api_core.exceptions import FailedPrecondition, ServiceUnavailable

from models.documind_models import AskRequest, AskResponse, Citation
from rag.ask.fact_context import build_facts_block, facts_snippet
from rag.categories import ALLOWED_CATEGORIES, expand_categories_for_query, normalize_category
from rag.pii_scrub import scrub_for_hosted
from rag.unit_resolution import resolve_unit_mention


class AskOrchestrator:
    """The LangGraph-driven chat flow: route intent -> conversation / finance /
    retrieve+answer."""

    def __init__(
        self, *, conversation_store, graph_orchestrator, hybrid_retriever, llm_getter,
        list_available_categories, get_property_name, list_property_units, get_finance_summary,
        get_document_facts=None,
    ):
        self._conversation_store = conversation_store
        self._graph_orchestrator = graph_orchestrator
        self._hybrid_retriever = hybrid_retriever
        self._llm_getter = llm_getter
        self._list_available_categories = list_available_categories
        self._get_property_name = get_property_name
        self._list_property_units = list_property_units
        self._get_finance_summary = get_finance_summary
        # Optional on purpose: a None getter yields no facts block, so every
        # existing construction site stays valid and the feature can never be
        # the reason an answer fails.
        self._get_document_facts = get_document_facts

    def _narrate_finance_summary(self, question: str, property_name: str, summary) -> str:
        """Turn the engine's computed JSON into a chat answer. The LLM narrates
        only — on any failure a deterministic headline line stands in, so the
        numbers shown are always the engine's."""
        totals = summary.totals
        top_caveat = summary.caveats[0] if summary.caveats else ""
        prompt = f"""You are DocuMind, answering a landlord's finance question.

**Question:** {question}
**Currently selected property (context only — figures below cover the whole portfolio):** {property_name}

**Computed figures for {summary.year} (authoritative):**
{summary.model_dump_json(indent=2)}

Rules:
1. Answer using ONLY the figures above, quoted exactly as given. NEVER recompute, derive, add, or estimate any number yourself.
2. If a figure the user wants is not present above, say it is not computed rather than deriving it.
3. When mentioning statutory rental income, always attach: "{totals.statutory_note}".
4. Include this caveat once: {top_caveat}
5. Amounts are in RM. Be concise; short bullet points are fine.

**Your Answer:**"""
        try:
            response = self._llm_getter().invoke(prompt)
            return response.content.strip()
        except Exception as e:
            print(f"❌ Finance narration failed: {e}")
            return (
                f"For {summary.year}: gross rent RM {totals.received_rent:,.2f}, "
                f"direct expenses RM {totals.direct_expenses:,.2f}, "
                f"net P/L RM {totals.net_pl:,.2f}. "
                f"Statutory rental income: RM {totals.statutory_rental_income:,.2f} "
                f"({totals.statutory_note})."
            )

    async def ask(self, payload: AskRequest, landlord_id: str) -> AskResponse:
        """
        Answer question using Firestore Vector Search.

        Flow:
        1. Generate embedding for question
        2. Vector search in Firestore (find_nearest)
        3. Build context from retrieved chunks
        4. Send to Gemini for answer synthesis
        5. Return answer with citations

        Args:
            payload: AskRequest with property_id, question, top_k
            landlord_id: Landlord ID derived from the verified auth token

        Returns:
            AskResponse with answer, citations, confidence
        """

        category_filter_mode = "all"
        available_categories = self._list_available_categories(landlord_id, payload.property_id)
        property_name = self._get_property_name(payload.property_id)

        # Normalize explicit category filters from payload
        requested_categories = payload.categories or []
        normalized_explicit = [category.strip().lower() for category in requested_categories if category and category.strip()]
        explicit_valid = [category for category in normalized_explicit if category in ALLOWED_CATEGORIES]

        session = self._conversation_store.get_or_create_session(
            landlord_id=landlord_id,
            property_id=payload.property_id,
            session_id=payload.session_id,
        )
        session_id = session.get("session_id")
        turn_number = max(1, self._conversation_store.get_turn_count(session_id) + 1)
        recent_turns = session.get("conversation_turns", []) if isinstance(session, dict) else []

        # Units go into the graph so the routing node can decide the unit
        # scope in the same LLM call that picks categories — but only when
        # that routing output would actually be read. It's discarded when the
        # frontend's unit picker already pinned unit_id. CategoryPredictor.
        # predict() already treats an empty unit list as "no unit routing
        # needed" (shorter prompt, no unit section), so this is a prompt-size
        # optimization, not a behavior change — a "whole property" session
        # still gets the full list, since that's the one path that reads it.
        property_units = self._list_property_units(payload.property_id)
        unit_already_resolved = bool(payload.unit_id)

        graph_state = await self._graph_orchestrator.run({
            "user_input": payload.question,
            "explicit_categories": explicit_valid,
            "available_categories": available_categories,
            "available_units": [] if unit_already_resolved else property_units,
            "recent_turns": recent_turns,
            "property_name": property_name,
        })

        graph_action = graph_state.get("action", "retrieve")
        predicted_categories = graph_state.get("predicted_categories", [])
        action_reason = graph_state.get("prediction_reason") or graph_state.get("intent_reason")

        # Conversational mode: no retrieval required yet
        if graph_action == "conversation":
            answer = graph_state.get(
                "assistant_message",
                "Hey! If you have anything that needs help with on property documents, please let me know.",
            )
            if property_name != "Unknown Property" and property_name.lower() not in answer.lower():
                answer = f"For {property_name}, {answer}"
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": graph_state.get("intent", "conversation"),
                    "action": "conversation",
                    "answer": answer,
                },
            )
            return AskResponse(
                answer=answer,
                confidence=graph_state.get("intent_confidence", 0.9),
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="conversation",
                session_id=session_id,
                conversation_turn=turn_number,
                predicted_categories=[],
                action_reason=graph_state.get("intent_reason"),
            )

        # Finance branch: skip retrieval entirely — the deterministic engine
        # computes, the LLM only narrates (2 LLM calls total incl. the router).
        if graph_action == "finance":
            requested_year = graph_state.get("finance_year") or datetime.now().year
            try:
                summary = await self._get_finance_summary(landlord_id, requested_year)
                answer = self._narrate_finance_summary(payload.question, property_name, summary)
            except Exception as e:
                print(f"❌ Finance summary failed: {e}")
                answer = (
                    "I couldn't compute your rental finances just now. "
                    "Please try again in a moment."
                )
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "finance_question",
                    "action": "finance",
                    "answer": answer,
                },
            )
            return AskResponse(
                answer=answer,
                confidence=0.9,
                citations=[],
                property_name=property_name,
                searched_categories=[],
                category_filter_mode="finance",
                session_id=session_id,
                conversation_turn=turn_number,
                predicted_categories=[],
                action_reason=graph_state.get("intent_reason"),
            )

        selected_categories: List[str] = []
        effective_unit_id = payload.unit_id

        if explicit_valid:
            selected_categories = explicit_valid[:10]
            category_filter_mode = "explicit"
        else:
            # Auto scope: apply the predicted categories only when the
            # predictor is reasonably confident; a weak prediction searches
            # the whole corpus rather than risking a wrong silent filter.
            if graph_state.get("prediction_confidence", 0.0) >= 0.45:
                selected_categories = [
                    category for category in predicted_categories if category in ALLOWED_CATEGORIES
                ]
            if selected_categories:
                category_filter_mode = "auto"

        # Unit routing (skipped when the unit picker already scopes the chat).
        # The search-router LLM decides the unit scope from the question when
        # it can (tool-style routing); when it couldn't, deterministic label
        # matching takes over. Either way explicit references route silently,
        # and a reference to a unit that does not exist gets an honest answer
        # listing the real ones.
        if effective_unit_id is None:
            unit_ids = {unit["unit_id"] for unit in property_units}
            routed_unit_id = graph_state.get("routed_unit_id")
            unknown_mention = graph_state.get("unknown_unit_mention")

            if unknown_mention:
                pass  # honest not-found answer below
            elif routed_unit_id and routed_unit_id in unit_ids:
                effective_unit_id = routed_unit_id
            elif not graph_state.get("unit_routing_decided"):
                unit_resolution = resolve_unit_mention(payload.question, property_units)
                if unit_resolution["kind"] == "scoped":
                    effective_unit_id = unit_resolution["unit"]["unit_id"]
                elif unit_resolution["kind"] == "unknown":
                    unknown_mention = unit_resolution["mention"]

            if unknown_mention:
                unit_labels = ", ".join(sorted(u["label"] for u in property_units))
                not_found_message = (
                    f"I couldn't find {unknown_mention} in {property_name}. "
                    f"This property's units are: {unit_labels}. "
                    "Ask about one of those, or ask without naming a unit to search everything."
                )
                self._conversation_store.append_turn(
                    session_id,
                    {
                        "turn": turn_number,
                        "question": payload.question,
                        "intent": "document_question",
                        "action": "unknown_unit",
                        "answer": not_found_message,
                    },
                )
                return AskResponse(
                    answer=not_found_message,
                    confidence=0.9,
                    citations=[],
                    property_name=property_name,
                    searched_categories=selected_categories,
                    category_filter_mode=category_filter_mode,
                    session_id=session_id,
                    conversation_turn=turn_number,
                    predicted_categories=predicted_categories,
                    action_reason="Question referenced a unit that does not exist",
                )

            # "ambiguous", "multi", "aggregate", and "none" all search
            # unscoped; the answer prompt attributes every fact to its unit.

        try:
            retrieved_chunks = await self._hybrid_retriever.retrieve(
                question=payload.question,
                landlord_id=landlord_id,
                property_id=payload.property_id,
                top_k=payload.top_k,
                categories=expand_categories_for_query(selected_categories) if selected_categories else None,
                unit_id=effective_unit_id,
            )
            print(f"✅ Retrieved {len(retrieved_chunks)} chunks (hybrid dense+rerank)")
        except Exception as e:
            # One catch-all used to report every failure as a vector-index
            # problem, which sent landlords to check an index that was usually
            # fine and hid the real cause in stdout. Each class now says
            # something true and actionable, and the traceback is always logged.
            print(f"❌ Hybrid retrieval failed: {type(e).__name__}: {e}")
            traceback.print_exc()
            if isinstance(e, FailedPrecondition):
                answer = ("Your document search index is still building. "
                          "Try again in a minute.")
                reason = "Vector index unavailable"
            elif isinstance(e, (ServiceUnavailable, ConnectionError, TimeoutError)):
                answer = ("Document search is temporarily unavailable. "
                          "Please try again shortly.")
                reason = "Retrieval backend unavailable"
            else:
                answer = "Something went wrong searching your documents."
                reason = "Retrieval failure"
            return AskResponse(
                answer=answer,
                confidence=0.0,
                citations=[],
                property_name=property_name,
                searched_categories=selected_categories,
                category_filter_mode=category_filter_mode,
                session_id=session_id,
                conversation_turn=turn_number,
                predicted_categories=predicted_categories,
                action_reason=reason,
            )

        if not retrieved_chunks:
            if selected_categories:
                category_hint = ", ".join(selected_categories)
                not_found_message = f"I couldn't find relevant information in your {category_hint} documents for {property_name}."
            else:
                not_found_message = f"I couldn't find relevant information in your documents for {property_name}."
            self._conversation_store.append_turn(
                session_id,
                {
                    "turn": turn_number,
                    "question": payload.question,
                    "intent": "document_question",
                    "action": "retrieve_no_result",
                    "searched_categories": selected_categories,
                    "answer": not_found_message,
                },
            )
            return AskResponse(
                answer=not_found_message,
                confidence=0.0,
                citations=[],
                property_name=property_name,
                searched_categories=selected_categories,
                category_filter_mode=category_filter_mode,
                session_id=session_id,
                conversation_turn=turn_number,
                predicted_categories=predicted_categories,
                action_reason="No chunks retrieved",
            )

        # No post-retrieval unit checkpoint: unit routing happened above from
        # the question text, and answers over mixed-unit chunks attribute every
        # fact to its unit (prompt rule 6) instead of blocking to ask.

        # Dedupe citations by (filename, page): multiple chunks can come from
        # the same page (overlapping splits), each with its own rerank score.
        # The LLM still sees every chunk's text via context_text below; this
        # only collapses what's shown as a citation, keeping the best score
        # per page so the same source never appears twice with two different
        # relevance bars.
        best_citation_by_page: dict[tuple[str, Optional[int]], dict] = {}
        context_text = ""
        for i, chunk in enumerate(retrieved_chunks):
            display_page = chunk['page'] + 1 if chunk.get('page') is not None else None
            page_key = (chunk['filename'], display_page)
            chunk_score = chunk.get('rerank_score', chunk.get('dense_score', 0.0))
            existing = best_citation_by_page.get(page_key)
            if existing is None or chunk_score > existing['score']:
                best_citation_by_page[page_key] = {
                    'doc_id': chunk['doc_id'],
                    'filename': chunk['filename'],
                    'category': normalize_category(chunk['category']),
                    'page': display_page,
                    'snippet': chunk['text'][:200],
                    'score': chunk_score,
                    'unit_id': chunk.get('unit_id'),
                    'unit_label': chunk.get('unit_label'),
                }
            unit_context = chunk.get('unit_label') or 'Property-wide'
            # PII gate: chunk text is the one place raw document content reaches
            # the hosted LLM. Scrub NRIC/phone/email here (citations to the app
            # keep the unscrubbed snippet — the user owns their own documents).
            safe_chunk_text = scrub_for_hosted(chunk['text'])
            context_text += f"\n\n[Document {i+1}: {chunk['filename']}, Page {display_page if display_page is not None else 'N/A'} — {unit_context}]\n{safe_chunk_text}"

        # Retrieval ranks prose about a value above the table that states it —
        # a lease Schedule loses to the clauses that cross-reference it. These
        # facts were parsed at upload, so hand them to the model directly
        # rather than hoping the right chunk won. Scoped to the documents this
        # query actually hit.
        facts_block = ""
        fact_rows = []
        if self._get_document_facts is not None:
            try:
                doc_ids = list(dict.fromkeys(c['doc_id'] for c in retrieved_chunks))
                fact_rows = list(self._get_document_facts(doc_ids))
                facts_block = scrub_for_hosted(
                    build_facts_block([(f, u, fa) for _, f, u, fa in fact_rows])
                )
            except Exception as e:
                print(f"WARNING: facts block unavailable, answering from excerpts only: {e}")
                facts_block = ""
                fact_rows = []

        citations = [
            Citation(
                doc_id=c['doc_id'],
                filename=c['filename'],
                category=c['category'],
                page=c['page'],
                snippet=c['snippet'],
                score=c['score'],
                unit_id=c['unit_id'],
                unit_label=c['unit_label'],
            )
            for c in sorted(best_citation_by_page.values(), key=lambda c: c['score'], reverse=True)
        ]

        # A value answered from extracted facts is not on any page we retrieved
        # — citing only those pages would send a landlord to verify a date that
        # is not there. Cite the facts themselves, page-less, with the value in
        # the snippet. Category and unit come from the chunk that pulled the
        # document in, so the badge matches the page citations beside it.
        chunk_meta = {
            c['doc_id']: (normalize_category(c['category']), c.get('unit_id'), c.get('unit_label'))
            for c in retrieved_chunks
        }
        for doc_id, filename, unit_label, facts in fact_rows:
            snippet = facts_snippet(facts)
            if not snippet:
                continue
            category, unit_id, chunk_unit_label = chunk_meta.get(doc_id, ('other', None, None))
            citations.insert(0, Citation(
                doc_id=doc_id,
                filename=filename,
                category=category,
                page=None,
                snippet=snippet,
                score=1.0,
                unit_id=unit_id,
                unit_label=unit_label or chunk_unit_label,
                source="extracted_facts",
            ))

        searched_categories_text = ", ".join(selected_categories) if selected_categories else "all categories"
        prompt = f"""You are DocuMind, an AI assistant specialized in property document management.

    **Your Purpose:**
    You help landlords understand their property documents across 7 categories:
    - Tenancy Agreements (lease terms, tenant details, rent, deposits, renewals)
    - Insurance Policies (coverage, premiums, policy periods)
    - Loans (loan agreements, bank interest statements)
    - Property Taxes (assessment tax, quit rent, parcel rent)
    - Upkeep (landlord-paid repairs and servicing)
    - Maintenance (management fees and sinking fund)
    - Rental Invoices (monthly rent billed to tenants)

    **User Question:**
    {payload.question}

    **Current Property:**
    {property_name}

    **Categories Searched:**
    {searched_categories_text}

    {("**Extracted Document Facts:**" + chr(10) + facts_block + chr(10)) if facts_block else ""}
    **Relevant Document Excerpts:**
    {context_text}

    **Instructions:**
    1. **IF** the question is about property documents (lease, insurance, loan, tax, upkeep, maintenance, rental invoices):
    - Answer based ONLY on the context above
    - Do NOT cite sources or mention filenames/pages — the app displays sources separately
    - Format dates clearly (e.g., "15 March 2026")
    - Keep your answer detailed and informative but organized and concise (bullet points or numbered lists)

    2. **IF** the question is off-topic (weather, sports, general knowledge, personal advice):
    - Accomodate and Politely redirect to your purpose

    3. **IF** you cannot find the answer in the context:
    If there is uploaded documents to reference:
    - Mention that the inquired information is not found in the uploaded documents and list out the documents you have searched, only in its relevant category.
    Else if there are no uploaded documents to reference:
    - Say "You do not have any relevant uploaded documents for that matter. Please upload a [category name] document to get answers about [specific topic]."

    4. **DO NOT** make up information - only use what's provided in the context.

    5. **Extracted facts take precedence for values.** The Extracted Document Facts block above, when present, holds values already parsed from these same documents at upload. When it answers the question, use it — the excerpts often only cross-reference a Schedule whose table is not among them. Never contradict that block with a guess, and never claim a value is unavailable when the block states it. Do NOT tell the user where the value came from — no "based on the extracted document facts", no mention of blocks, excerpts or parsing. Just answer; the app shows sources separately.

    6. **Unit attribution:** Each excerpt header names the unit it belongs to (or "Property-wide"). Never blend values from different units — attribute every figure to its unit. If the excerpts span multiple units, break the answer down per unit (e.g. "Unit A-12-03: ...", "Unit B-08-11: ..."). For totals across units, show each unit's value and then the combined total. Property-wide documents apply to the whole property.

    **Your Answer:**"""

        try:
            response = self._llm_getter().invoke(prompt)
            answer = response.content.strip()
            print(f"✅ Generated answer: {answer[:100]}...")
        except Exception as e:
            print(f"❌ Gemini answer generation failed: {e}")
            answer = "I encountered an error generating an answer. Please try again."

        response = AskResponse(
            answer=answer,
            confidence=0.95,  # Mock confidence
            citations=citations,
            property_name=property_name,
            searched_categories=selected_categories,
            category_filter_mode=category_filter_mode,
            session_id=session_id,
            conversation_turn=turn_number,
            predicted_categories=predicted_categories,
            action_reason=action_reason,
        )

        self._conversation_store.append_turn(
            session_id,
            {
                "turn": turn_number,
                "question": payload.question,
                "intent": "document_question",
                "action": "retrieve",
                "searched_categories": selected_categories,
                "answer": answer,
            },
        )

        return response
