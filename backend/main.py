from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.rex_routes import router as rex_router
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Rex AI Backend",
    description="Lease Generator & DocuMind API with Firestore Vector Search",
    version="2.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(rex_router)

@app.get("/")
async def root():
    return {
        "message": "Rex AI Backend API",
        "version": "2.0.0",
        "features": ["Lease Generator", "DocuMind (Firestore Vector Search)"]
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "database": "Firestore"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)