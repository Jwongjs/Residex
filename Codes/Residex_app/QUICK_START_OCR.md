# OCR Quick Start - PRODUCTION VERSION

**Goal:** Get Google Cloud Vision + Gemini Flash working in 1.5 hours

---

## TL;DR - Copy-Paste Commands

### Phase 1: Google Cloud (Manual - 30 min)
1. Go to https://console.cloud.google.com/
2. Create project: `splitlah-ocr-prod`
3. Enable APIs:
   - Cloud Vision API
   - Generative Language API (Gemini)
4. Create API key
5. Restrict key to both APIs
6. Copy API key

### Phase 2: Environment Setup (5 min)
```powershell
# Set API key permanently
[System.Environment]::SetEnvironmentVariable('GOOGLE_API_KEY', 'AIza...your-key-here', 'User')

# Verify
echo $env:GOOGLE_API_KEY

# Activate venv & install
cd D:\Projects\Bill_Splitter_App\ocr_training
venv\Scripts\activate
pip install google-cloud-vision google-generativeai flask flask-cors pillow
```

### Phase 3: Test Everything (10 min)
```bash
# Test Google Vision
python test_google_vision.py

# Test Gemini
python test_gemini.py

# Test full pipeline
python gemini_receipt_processor.py "D:\Projects\Bill_Splitter_App\ocr_training\SROIE2019\train\img\X00016469612.jpg"

# Batch test
python batch_test_gemini.py

# Check costs
python cost_calculator.py
```

### Phase 4: Run API (5 min)
```bash
# Terminal 1: Start API
python flask_gemini_api.py

# Terminal 2: Test API
python test_gemini_api.py
```

---

## Files You'll Create

```
ocr_training/
├── test_google_vision.py            ✅ Test Vision API
├── test_gemini.py                   ✅ Test Gemini
├── gemini_receipt_processor.py      ✅ Main processor
├── batch_test_gemini.py             ✅ Batch testing
├── cost_calculator.py               ✅ Cost estimates
├── flask_gemini_api.py              ✅ API server
├── test_gemini_api.py               ✅ API tests
├── API_DOCUMENTATION.md             ✅ API docs
└── DEPLOYMENT.md                    ✅ Deploy guide
```

---

## Success Checklist

**You're ready when:**
- ✅ `python test_google_vision.py` → "Client initialized!"
- ✅ `python test_gemini.py` → JSON response
- ✅ `python gemini_receipt_processor.py <image>` → Extracted items
- ✅ `python flask_gemini_api.py` → Server on port 5000
- ✅ `python test_gemini_api.py` → Receipt data returned
- ✅ `python cost_calculator.py` → Shows ~$0.0015/receipt

---

## Quick Troubleshooting

**"GOOGLE_API_KEY not set":**
```powershell
# Check if set
echo $env:GOOGLE_API_KEY

# Set permanently
[System.Environment]::SetEnvironmentVariable('GOOGLE_API_KEY', 'your-key', 'User')

# Restart terminal
```

**"API not enabled":**
- Go to Google Cloud Console
- Enable "Cloud Vision API"
- Enable "Generative Language API"

**"Billing not enabled":**
- Go to Billing → Enable billing
- Add $300 free credit automatically activates

---

## Cost Summary

**Per receipt:** ~$0.0015 (RM0.007)
**With $300 credit:** ~193,000 receipts FREE
**Monthly (100 receipts):** $0.16/month after free tier

**This is CHEAP for production!**

---

## What's Next?

**After OCR is working:**
1. Continue Flutter refactoring ← Focus here
2. Keep API running in background
3. Integrate when ready

**OCR is production-ready - go clean your app!**

---

## Key Differences vs Local LLM

| Feature | Gemini Flash | Local Qwen |
|---------|-------------|------------|
| Setup time | 1.5 hours | 2+ hours |
| Always available | ✅ Yes | ❌ Only when laptop on |
| Scalable | ✅ Infinite | ❌ Limited to GPU |
| Production ready | ✅ Yes | ❌ Needs server setup |
| Cost (1k receipts) | $1.55 | $0 (+ electricity) |
| Speed | 0.5-1.5s | 1-2s |

**Winner: Gemini Flash for production apps!**
