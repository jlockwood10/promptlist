# PromptList

> _SecLists for the age of hallucination._

Wordlists for discovering AI-related API endpoints with `ffuf`, `gobuster`, `feroxbuster`, etc. Compiled from official API documentation across 50+ AI providers, model-serving frameworks, LLM gateways, agent frameworks, RAG/vector DBs, and AI SaaS products.

## Files

| File | Lines | Use when |
|---|---|---|
| `ai-endpoints-full.txt` | 6,322 | **Recommended.** Full paths **plus** every intermediate prefix (`v1`, `v1/chat`, `v1/chat/completions`, etc.). |
| `ai-endpoints.txt` | 5,498 | Full endpoint paths only. No leading `/`. Path params as `{name}`. |
| `ai-prefixes.txt` | 6,282 | Every cumulative prefix of every endpoint — for finding API roots, version paths, and parent collections. |
| `ai-endpoints-with-slash.txt` | 5,498 | Same as `ai-endpoints.txt` but each prefixed with `/`. |
| `ai-endpoints-no-params.txt` | 3,551 | Paths truncated at the first `{param}` — clean collection paths only. |
| `ai-segments.txt` | 1,614 | Single path segments — fuzz one directory at a time. |
| `sources/` | — | Per-provider raw source files. Edit + rerun `build.sh` to regenerate. |

## Usage

```bash
# ffuf
ffuf -w ai-endpoints.txt -u https://target.example.com/FUZZ -mc 200,201,204,301,302,401,403

# gobuster
gobuster dir -w ai-endpoints.txt -u https://target.example.com -s 200,201,204,301,302,401,403 -b ""

# Path params: replace {placeholder} with a value list first
sed 's|{[^}]*}|FUZZ|g' ai-endpoints.txt | sort -u > ai-endpoints-fuzz.txt
ffuf -w ai-endpoints-fuzz.txt:FILE -w ids.txt:FUZZ -u https://target.example.com/FILE

# Single-segment discovery (one level at a time)
ffuf -w ai-segments.txt -u https://target.example.com/api/FUZZ
```

## Coverage

- **Tier-1 model providers**: OpenAI (incl. Assistants, Responses, Realtime, Vector Stores, Admin), Anthropic (Messages, Batches, Admin, Compliance, Managed Agents), Google Gemini + Vertex AI (publishers, endpoints, reasoning engines, RAG corpora, feature stores).
- **Cloud AI**: Azure OpenAI / AI Foundry (both legacy and v1 shapes), AWS Bedrock (runtime, control plane, agents, knowledge bases, flows), AWS SageMaker (runtime + control plane ops), HuggingFace (Hub, Inference API, dedicated Inference Endpoints v2/v3).
- **Second-tier providers**: Cohere, Mistral, Replicate, Together, Groq, Perplexity, Stability, DeepSeek, xAI Grok, ElevenLabs, Fireworks, OpenRouter, Modal, RunPod, Lambda Labs, Anyscale, LangSmith.
- **Vector DBs**: Pinecone, Weaviate, Qdrant, Chroma, Milvus.
- **LLM gateways**: LiteLLM, Helicone, Portkey, Kong AI Gateway, Cloudflare AI Gateway, Vercel AI SDK.
- **Chat / agent frontends**: Open WebUI, LibreChat, AnythingLLM, NextChat, LobeChat, Chatbot UI, BetterChatGPT, Open Assistant.
- **Agent frameworks**: LangServe, LangGraph Cloud, LlamaIndex deploy, AutoGPT, CrewAI, AutoGen Studio, Hayhooks, Microsoft Bot Framework, Rasa, Dialogflow ES/CX.
- **Model serving**: Triton, vLLM, TGI, Ollama, llama.cpp server, LocalAI, KServe v1+v2, Ray Serve, TorchServe, Cortex, BentoML.
- **MCP**: Stream/SSE transports, JSON-RPC method paths, OAuth discovery `/.well-known/*`.
- **AI SaaS**: Notion AI, Slack AI, Salesforce Einstein, IBM watsonx, OctoAI.

## Regenerating

Edit any file in `sources/`, then:

```bash
./build.sh
```

The script strips comments/blanks/leading slashes, dedupes, and produces all four output files.
