"""
DocuMind API Testing Script
Tests all DocuMind endpoints with a real PDF document
"""

import requests
import json
import os
from pathlib import Path

BASE_URL = "http://localhost:8000/api/rex"

# Test parameters
LANDLORD_ID = "test_landlord"
PROPERTY_ID = "property_1"
CATEGORY = "warranty"
PDF_PATH = r"C:\Users\user\Downloads\Warranty-Card-RAC.pdf"

def print_section(title):
    """Print a formatted section header"""
    print("\n" + "="*80)
    print(f"  {title}")
    print("="*80 + "\n")

def test_upload_document():
    """Test 1: Upload a PDF document"""
    print_section("TEST 1: Upload Document")
    
    # Check if file exists
    if not os.path.exists(PDF_PATH):
        print(f"❌ ERROR: PDF file not found at {PDF_PATH}")
        return None
    
    print(f"📄 File: {PDF_PATH}")
    print(f"📦 Size: {os.path.getsize(PDF_PATH)} bytes")
    print(f"🏢 Landlord ID: {LANDLORD_ID}")
    print(f"🏠 Property ID: {PROPERTY_ID}")
    print(f"📁 Category: {CATEGORY}")
    print("\n⏳ Uploading document...")
    
    try:
        with open(PDF_PATH, 'rb') as f:
            files = {'file': (os.path.basename(PDF_PATH), f, 'application/pdf')}
            data = {
                'landlord_id': LANDLORD_ID,
                'property_id': PROPERTY_ID,
                'category': CATEGORY
            }
            
            response = requests.post(
                f"{BASE_URL}/documind/upload",
                files=files,
                data=data,
                timeout=120
            )
        
        print(f"📊 Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Upload successful!")
            print(f"\n📋 Response:")
            print(json.dumps(result, indent=2))
            return result.get('doc_id')
        else:
            print(f"❌ Upload failed!")
            print(f"Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Error during upload: {e}")
        return None


def test_list_documents():
    """Test 2: List uploaded documents"""
    print_section("TEST 2: List Documents")
    
    print(f"🏢 Landlord ID: {LANDLORD_ID}")
    print(f"🏠 Property ID: {PROPERTY_ID}")
    print("\n⏳ Fetching document list...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/documind/documents",
            params={
                'landlord_id': LANDLORD_ID,
                'property_id': PROPERTY_ID
            },
            timeout=30
        )
        
        print(f"📊 Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Request successful!")
            print(f"\n📋 Response:")
            print(json.dumps(result, indent=2))
            print(f"\n📚 Total documents: {result.get('total', 0)}")
            
            # Show document summary
            if result.get('documents'):
                print("\n📄 Documents:")
                for i, doc in enumerate(result['documents'], 1):
                    print(f"  {i}. {doc['filename']} (ID: {doc['doc_id']})")
                    print(f"     Category: {doc['category']} | Chunks: {doc['chunks_indexed']}")
            
            return result.get('documents', [])
        else:
            print(f"❌ Request failed!")
            print(f"Response: {response.text}")
            return []
            
    except Exception as e:
        print(f"❌ Error listing documents: {e}")
        return []


def test_ask_question(question):
    """Test 3: Ask a question about the uploaded documents"""
    print_section("TEST 3: Ask Question")
    
    print(f"💬 Question: {question}")
    print(f"🏢 Landlord ID: {LANDLORD_ID}")
    print(f"🏠 Property ID: {PROPERTY_ID}")
    print("\n⏳ Processing question...")
    
    try:
        response = requests.post(
            f"{BASE_URL}/documind/ask",
            json={
                'landlord_id': LANDLORD_ID,
                'property_id': PROPERTY_ID,
                'question': question
            },
            timeout=60
        )
        
        print(f"📊 Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Request successful!")
            print(f"\n💡 Answer:")
            print(f"  {result.get('answer', 'No answer provided')}")
            
            if result.get('citations'):
                print(f"\n📚 Citations ({len(result['citations'])}):")
                for i, cite in enumerate(result['citations'], 1):
                    print(f"  {i}. {cite['filename']} (page {cite.get('page', 'N/A')})")
                    print(f"     Relevance: {cite.get('relevance_score', 0):.3f}")
            
            return result
        else:
            print(f"❌ Request failed!")
            print(f"Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Error asking question: {e}")
        return None


def main():
    """Run all tests"""
    print("\n🚀 DocuMind API Testing")
    print(f"🌐 Backend URL: {BASE_URL}")
    print(f"📅 Test Date: {os.popen('date /t').read().strip()}")
    
    # Test 1: Upload document
    doc_id = test_upload_document()
    
    if not doc_id:
        print("\n❌ Upload failed. Cannot continue with other tests.")
        return
    
    # Test 2: List documents
    documents = test_list_documents()
    
    # Test 3: Ask questions
    questions = [
        "What is this warranty about?",
        "What is covered under this warranty?",
        "How long is the warranty valid?"
    ]
    
    for question in questions:
        test_ask_question(question)
    
    # Final summary
    print_section("TEST SUMMARY")
    print("✅ All tests completed!")
    print(f"📄 Document uploaded: {doc_id}")
    print(f"📚 Total documents in property: {len(documents)}")
    print("\n🎉 Testing complete!")


if __name__ == "__main__":
    main()
