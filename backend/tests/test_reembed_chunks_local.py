import unittest

from scripts.reembed_chunks_local import plan_reembeddings


class _FakeEmb:
    """Records each batched call; returns a deterministic vector keyed on the
    text so tests can assert the id->vector mapping (values are synthetic)."""

    def __init__(self):
        self.calls = []

    def embed_documents(self, texts):
        self.calls.append(list(texts))
        return [[float(len(t))] + [0.0] * 767 for t in texts]


class PlanReembeddingsTests(unittest.TestCase):
    def test_maps_each_chunk_id_to_its_vector_in_order(self):
        emb = _FakeEmb()
        plan = plan_reembeddings(
            [{"id": "a", "text": "alpha"}, {"id": "b", "text": "bb"}], emb
        )
        self.assertEqual([cid for cid, _ in plan], ["a", "b"])
        self.assertEqual(plan[0][1][0], 5.0)  # len("alpha")
        self.assertEqual(plan[1][1][0], 2.0)  # len("bb")

    def test_skips_empty_and_whitespace_text(self):
        emb = _FakeEmb()
        plan = plan_reembeddings(
            [{"id": "a", "text": ""}, {"id": "b", "text": "   "}, {"id": "c", "text": "x"}],
            emb,
        )
        self.assertEqual([cid for cid, _ in plan], ["c"])
        self.assertEqual(emb.calls, [["x"]])  # only the non-empty text embedded

    def test_batches_by_window_not_per_chunk(self):
        emb = _FakeEmb()
        chunks = [{"id": str(i), "text": f"t{i}"} for i in range(5)]
        plan = plan_reembeddings(chunks, emb, batch_size=2)
        self.assertEqual(len(plan), 5)
        self.assertEqual([len(call) for call in emb.calls], [2, 2, 1])  # 3 batched calls

    def test_empty_input_makes_no_embed_calls(self):
        emb = _FakeEmb()
        self.assertEqual(plan_reembeddings([], emb), [])
        self.assertEqual(emb.calls, [])


if __name__ == "__main__":
    unittest.main()
