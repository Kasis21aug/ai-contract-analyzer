from fastapi import FastAPI

app = FastAPI(title="Contract Analyzer API")


@app.get("/api/health")
def health():
    return {"status": "ok"}