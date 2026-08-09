# Aixgo Configuration Examples

Comprehensive collection of YAML configuration examples for Aixgo agents, LLM providers, MCP servers, security modes, orchestration patterns, and real-world use cases.

## Table of Contents

- [Agent Types](#agent-types) (6 examples)
- [LLM Providers](#llm-providers) (6 examples)
- [MCP Integration](#mcp-integration) (3 examples)
- [Security Configurations](#security-configurations) (4 examples)
- [Orchestration Patterns](#orchestration-patterns) (13 examples)
- [Use Cases](#use-cases) (4 examples)

---

## Agent Types

Agent types define the behavior and capabilities of individual agents in your Aixgo deployment.

### [Producer Agent](https://github.com/aixgo-dev/aixgo/blob/main/examples/agents/producer.yaml)

Generates messages at regular intervals for downstream processing.

**Use Cases:** Data streaming, event generation, monitoring, load testing

**Key Features:**

- Configurable interval timing
- Fan-out to multiple consumers
- Synthetic data generation
- Timestamp and ID tracking

### [ReAct Agent](https://github.com/aixgo-dev/aixgo/blob/main/examples/agents/react.yaml)

Reasoning and Acting agent with tool use capabilities. Implements the ReAct pattern: Thought → Action → Observation.

**Use Cases:** Question answering, research tasks, data retrieval, API integrations

**Key Features:**

- LLM-powered reasoning
- Tool calling / function calling
- JSON schema validation
- Multi-turn conversations
- Supports all major LLM providers

### [Logger Agent](https://github.com/aixgo-dev/aixgo/blob/main/examples/agents/logger.yaml)

Simple logging agent that outputs messages to stdout/logs.

**Use Cases:** Debugging, monitoring, audit trails, development

**Key Features:**

- Multi-input aggregation
- No configuration required
- Immediate output (no buffering)
- Message type and payload logging

### [Classifier Agent](https://github.com/aixgo-dev/aixgo/blob/main/examples/agents/classifier.yaml)

AI-powered content classification with semantic understanding.

**Use Cases:** Content categorization, intent detection, routing, triage

**Key Features:**

- Multi-label classification
- Few-shot learning
- Confidence scoring
- Semantic similarity
- Performance metrics tracking
- Alternative suggestions

### [Aggregator Agent](https://github.com/aixgo-dev/aixgo/blob/main/examples/agents/aggregator.yaml)

AI-powered aggregation of multiple agent outputs.

**Use Cases:** Consensus building, result synthesis, multi-agent coordination

**Key Features:**

- Multiple aggregation strategies (consensus, weighted, semantic, hierarchical, RAG)
- Conflict resolution
- Deduplication
- Semantic clustering
- Source attribution
- Performance analytics

**Strategies:**

- **Consensus:** Find common ground among inputs
- **Weighted:** Prioritize certain sources
- **Semantic:** Group by similarity
- **Hierarchical:** Multi-level aggregation
- **RAG-based:** Retrieval-augmented generation

### [Planner Agent](https://github.com/aixgo-dev/aixgo/blob/main/examples/agents/planner.yaml)

AI-powered Chain-of-Thought planning and reasoning.

**Use Cases:** Task decomposition, strategic planning, project management, workflow design

**Key Features:**

- Multiple planning strategies
- Self-critique and improvement
- Parallel step identification
- Risk assessment
- Backup plans
- Success criteria
- Performance tracking

**Strategies:**

- **Chain-of-Thought:** Linear reasoning
- **Tree-of-Thought:** Explore branches
- **ReAct Planning:** Thought-Action-Observation
- **Backward Chaining:** Goal-oriented
- **Hierarchical:** Multi-level decomposition
- **Monte Carlo:** Simulate multiple paths

---

## LLM Providers

Configuration examples for different LLM providers supported by aixgo.

### [OpenAI](https://github.com/aixgo-dev/aixgo/blob/main/examples/llm-providers/openai.yaml)

GPT-3.5, GPT-4, and OpenAI-compatible endpoints.

**Models:** gpt-3.5-turbo, gpt-4, gpt-4-turbo

**Features:**

- Function calling
- JSON mode
- Vision (GPT-4V)
- Streaming
- Fine-tuning support (GPT-3.5)

**Cost:** $0.001-$0.06 per 1K tokens (varies by model)

**Best For:** Production deployments, complex reasoning, high accuracy

### [Anthropic Claude](https://github.com/aixgo-dev/aixgo/blob/main/examples/llm-providers/anthropic.yaml)

Claude 3 family: Haiku, Sonnet, and Opus.

**Models:** claude-3-haiku, claude-3-sonnet, claude-3-opus

**Features:**

- 200K context window
- Vision support
- Tool use
- Constitutional AI
- Extended thinking
- JSON mode

**Cost:** $0.25-$75 per MTok (varies by model)

**Best For:** Long documents, complex reasoning, safety-critical applications

### [Google Gemini](https://github.com/aixgo-dev/aixgo/blob/main/examples/llm-providers/gemini.yaml)

Gemini Pro and Gemini Pro Vision via Google AI Studio.

**Models:** gemini-pro, gemini-pro-vision

**Features:**

- Free tier available
- Native multimodal
- Function calling
- Grounding (experimental)
- Safety settings

**Cost:** Free tier, then usage-based

**Best For:** Development, testing, image understanding

### [Google Vertex AI](https://github.com/aixgo-dev/aixgo/blob/main/examples/llm-providers/vertexai.yaml)

Enterprise Gemini and PaLM on Google Cloud Platform.

**Models:** gemini-pro, text-bison, code-bison

**Features:**

- Enterprise SLAs
- VPC-SC security
- CMEK encryption
- Regional deployment
- Audit logging
- Compliance certifications

**Cost:** $0.00025-$0.0005 per 1K chars

**Best For:** Enterprise production, compliance requirements, GCP integration

### [xAI Grok](https://github.com/aixgo-dev/aixgo/blob/main/examples/llm-providers/xai.yaml)

Grok models from xAI (X.AI).

**Models:** grok-beta, grok-1

**Features:**

- Real-time information
- X (Twitter) integration
- Witty personality
- OpenAI-compatible API
- Function calling

**Best For:** Current events, social media analysis, conversational interfaces

### [HuggingFace](https://github.com/aixgo-dev/aixgo/blob/main/examples/llm-providers/huggingface.yaml)

Open-source models via HuggingFace Inference API.

**Models:** Llama 2, Mistral, CodeLlama, Falcon, and more

**Features:**

- Serverless and dedicated endpoints
- Custom model deployment
- Cost-effective
- Model transparency
- Self-hosting option

**Cost:** Free tier, then ~$0.06 per 1K tokens or GPU rental

**Best For:** Cost optimization, transparency, customization, self-hosting

---

## MCP Integration

Model Context Protocol (MCP) enables agents to use external tools and services.

### [Local Transport](https://github.com/aixgo-dev/aixgo/blob/main/examples/mcp/local-transport.yaml)

In-process MCP server communication (same process).

**Use Cases:** Development, testing, embedded tools

**Advantages:**

- No network overhead (fastest)
- Simple configuration
- Secure (no network exposure)
- Easy debugging

**Best For:** Development, single-process applications, performance-critical tools

### [gRPC Transport](https://github.com/aixgo-dev/aixgo/blob/main/examples/mcp/grpc-transport.yaml)

Remote MCP server communication via gRPC.

**Use Cases:** Production, microservices, distributed systems

**Features:**

- TLS/mTLS via cloud infrastructure (Cloud Run, GKE, service mesh)
- HTTP/2 multiplexing
- Streaming support
- Load balancing
- Health checking

**Best For:** Production deployments, service isolation, distributed architectures

### [Multiple Servers](https://github.com/aixgo-dev/aixgo/blob/main/examples/mcp/multiple-servers.yaml)

Connecting to multiple MCP servers simultaneously.

**Use Cases:** Hybrid architectures, tool aggregation, complex workflows

**Features:**

- Mix local and remote servers
- Automatic tool discovery
- Tool routing
- Independent scaling
- Failure isolation

**Best For:** Production systems requiring diverse tool sources

---

## Security Configurations

Security modes for different deployment environments.

### [Disabled (Development)](https://github.com/aixgo-dev/aixgo/blob/main/examples/security/disabled-dev.yaml)

No authentication or authorization.

**WARNING:** Development only! Never use in production!

**Use Cases:** Local development, unit testing, prototyping

**Features:**

- No authentication
- No access control
- Minimal logging
- Fast iteration

### [Builtin API Key](https://github.com/aixgo-dev/aixgo/blob/main/examples/security/builtin-api-key.yaml)

Application-level authentication using API keys.

**Use Cases:** Service-to-service, API access, automation

**Features:**

- Environment or file-based keys
- Per-key identification
- Rate limiting support
- Audit logging
- Key rotation support

**Best For:** Machine-to-machine authentication, CI/CD pipelines

### [Delegated (IAP)](https://github.com/aixgo-dev/aixgo/blob/main/examples/security/delegated-iap.yaml)

Infrastructure-level authentication via Google Cloud IAP.

**Use Cases:** Internal tools, dashboards, human users

**Features:**

- Google account authentication
- MFA support
- Centralized access control
- Cloud Logging integration
- No credential management

**Best For:** Cloud Run, GKE deployments with human users

### [Hybrid](https://github.com/aixgo-dev/aixgo/blob/main/examples/security/hybrid.yaml)

Combines delegated (IAP) and builtin (API key) authentication.

**Use Cases:** Mixed client types (humans + services)

**Features:**

- IAP for human users
- API keys for services
- Unified authorization
- Comprehensive audit
- Flexible client support

**Best For:** Production systems with diverse client types

---

## Orchestration Patterns

Multi-agent coordination patterns managed by supervisors.

### [MapReduce](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/mapreduce.yaml)

Distribute work across agents, then aggregate results.

**Pattern:** Map phase → Reduce phase

**Use Cases:** Data processing, distributed analysis, parallel workloads

**Characteristics:**

- Horizontal scaling
- Parallel processing
- Result aggregation

### [Parallel](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/parallel.yaml)

Multiple agents work independently on the same input.

**Pattern:** All agents process simultaneously

**Use Cases:** Multi-perspective analysis, redundancy, speed

**Characteristics:**

- Independent execution
- Concurrent processing
- Diverse viewpoints

### [Sequential](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/sequential.yaml)

Chain of agents in sequence, each building on previous output.

**Pattern:** Agent 1 → Agent 2 → Agent 3 → ...

**Use Cases:** Multi-step workflows, pipeline processing

**Characteristics:**

- Ordered execution
- Intermediate results
- Step-by-step refinement

### [Reflection](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/reflection.yaml)

Agent critiques and improves its own output.

**Pattern:** Generate → Critique → Refine

**Use Cases:** Quality improvement, self-correction

**Characteristics:**

- Iterative refinement
- Self-critique
- Quality enhancement

### [Planning](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/planning.yaml)

Plan the approach first, then execute the plan.

**Pattern:** Plan → Execute

**Use Cases:** Complex tasks, strategic execution

**Characteristics:**

- Upfront planning
- Structured execution
- Clear strategy

### [Classification](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/classification.yaml)

Route requests based on content classification.

**Pattern:** Classify → Route → Process

**Use Cases:** Content routing, triage, specialized handling

**Characteristics:**

- Content-aware routing
- Specialized agents
- Efficient distribution

### [Supervisor](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/supervisor.yaml)

Hub-and-spoke coordination where supervisor delegates to specialists.

**Pattern:** Supervisor receives requests, routes to specialists, aggregates responses

**Use Cases:** Customer service, research tasks, content pipelines

**Characteristics:**

- Centralized control
- Simple reasoning
- Easy debugging

### [Router](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/router.yaml)

Intelligent cost-optimized routing.

**Pattern:** Classify input → Route to appropriate agent

**Use Cases:** Cost optimization (25-50% savings), intent routing, model selection

**Characteristics:**

- Two-stage (classify → route)
- Low latency
- Cost-effective

### [Swarm](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/swarm.yaml)

Decentralized agent handoffs.

**Pattern:** Agents hand off to other agents dynamically

**Use Cases:** Customer support handoffs, troubleshooting, adaptive routing

**Characteristics:**

- Mesh topology
- Agent-driven routing
- Dynamic delegation

### [Hierarchical](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/hierarchical.yaml)

Multi-level delegation.

**Pattern:** Manager → Sub-managers → Workers

**Use Cases:** Project management, enterprise workflows, complex decomposition

**Characteristics:**

- Tree topology
- Scalable coordination
- Multi-level structure

### [RAG](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/rag.yaml)

Retrieval-Augmented Generation.

**Pattern:** Retrieve relevant docs → Generate grounded response

**Use Cases:** Documentation Q&A, knowledge management, enterprise search

**Characteristics:**

- Vector search
- Reduced hallucinations
- Knowledge grounding

### [Ensemble](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/ensemble.yaml)

Multi-model voting.

**Pattern:** Multiple models vote → Aggregate consensus

**Use Cases:** High-stakes decisions, medical diagnosis, content moderation

**Characteristics:**

- 25-50% error reduction
- Parallel execution
- Consensus-based

### [Aggregation](https://github.com/aixgo-dev/aixgo/blob/main/examples/orchestration/aggregation.yaml)

Multi-agent synthesis.

**Pattern:** Collect outputs → Apply aggregation strategy → Synthesize result

**Use Cases:** Research synthesis, distributed decisions, multi-perspective analysis

**Characteristics:**

- Multiple strategies (consensus, weighted, semantic)
- Conflict resolution
- Source attribution

---

## Use Cases

Real-world application examples combining agents and patterns.

### [Simple Chatbot](https://github.com/aixgo-dev/aixgo/blob/main/examples/use-cases/simple-chatbot.yaml)

Basic conversational AI assistant.

**Components:**

- ReAct agent with GPT-4
- Tool for time/date queries
- Friendly, helpful personality

**Use Cases:**

- Customer support
- Information retrieval
- General Q&A

### [Content Classifier](https://github.com/aixgo-dev/aixgo/blob/main/examples/use-cases/content-classifier.yaml)

Categorize and route incoming content.

**Components:**

- Classifier agent
- Multiple categories (spam, support, sales)
- Confidence thresholds

**Use Cases:**

- Email triage
- Support ticket routing
- Content moderation

### [Multi-Expert Consensus](https://github.com/aixgo-dev/aixgo/blob/main/examples/use-cases/multi-expert-consensus.yaml)

Multiple expert agents reach consensus.

**Components:**

- 3 expert agents (different models)
- Aggregator for consensus
- High confidence threshold

**Use Cases:**

- Critical decisions
- Multi-perspective analysis
- Quality assurance

### [Task Planner](https://github.com/aixgo-dev/aixgo/blob/main/examples/use-cases/task-planner.yaml)

Break down complex tasks into executable steps.

**Components:**

- Planner agent with Chain-of-Thought
- Self-critique enabled
- Alternative generation

**Use Cases:**

- Project management
- Workflow design
- Strategic planning

---

## Getting Started

### Running an Example

```bash
# Set required environment variables
export OPENAI_API_KEY="your-key-here"

# Run an example configuration
aixgo run examples/agents/react.yaml
```

### Combining Examples

You can combine elements from different examples:

```yaml
# Use security from security/builtin-api-key.yaml
environment: production
auth_mode: builtin

# Use agents from agents/react.yaml
agents:
  - name: my-agent
    role: react
    model: gpt-4
    # ... rest of config
```

### Environment Variables

Most examples require environment variables for API keys:

```bash
# OpenAI
export OPENAI_API_KEY="sk-..."

# Anthropic
export ANTHROPIC_API_KEY="sk-ant-..."

# Google
export GOOGLE_API_KEY="AIza..."
export VERTEX_PROJECT_ID="my-project"

# xAI
export XAI_API_KEY="xai-..."

# HuggingFace
export HUGGINGFACE_API_KEY="hf_..."
```

### Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** or secrets management
3. **Enable authentication** in production (never use disabled mode)
4. **Enable audit logging** for compliance
5. **Deploy with TLS** - Cloud Run, GKE, and service mesh provide TLS by default
6. **Implement rate limiting** per client
7. **Monitor** all authentication attempts
8. **Rotate credentials** regularly

### Performance Tips

1. **Use appropriate model sizes** (don't over-provision)
2. **Local MCP** for low-latency tools
3. **Remote MCP** for scalability
4. **Cache** frequent queries
5. **Streaming** for better UX
6. **Monitor** token usage and costs
7. **Batch** where possible
8. **Parallel** execution for independent tasks

---

## File Organization

```text
examples/
├── README.md (this file)
├── agents/ (6 examples)
│   ├── producer.yaml
│   ├── react.yaml
│   ├── logger.yaml
│   ├── classifier.yaml
│   ├── aggregator.yaml
│   └── planner.yaml
├── llm-providers/ (6 examples)
│   ├── openai.yaml
│   ├── anthropic.yaml
│   ├── gemini.yaml
│   ├── vertexai.yaml
│   ├── xai.yaml
│   └── huggingface.yaml
├── mcp/ (3 examples)
│   ├── local-transport.yaml
│   ├── grpc-transport.yaml
│   └── multiple-servers.yaml
├── security/ (4 examples)
│   ├── disabled-dev.yaml
│   ├── builtin-api-key.yaml
│   ├── delegated-iap.yaml
│   └── hybrid.yaml
├── orchestration/ (13 examples)
│   ├── mapreduce.yaml
│   ├── parallel.yaml
│   ├── sequential.yaml
│   ├── reflection.yaml
│   ├── planning.yaml
│   ├── classification.yaml
│   ├── supervisor.yaml
│   ├── router.yaml
│   ├── swarm.yaml
│   ├── hierarchical.yaml
│   ├── rag.yaml
│   ├── ensemble.yaml
│   └── aggregation.yaml
└── use-cases/ (4 examples)
    ├── simple-chatbot.yaml
    ├── content-classifier.yaml
    ├── multi-expert-consensus.yaml
    └── task-planner.yaml
```

**Total:** 36 comprehensive, production-ready examples

---

## Additional Resources

- **Documentation:** [aixgo.dev](https://aixgo.dev)
- **GitHub:** [github.com/aixgo-dev/aixgo](https://github.com/aixgo-dev/aixgo)
- **API Reference:** See `/docs/api`
- **Deployment Guides:** See `/docs/deployment`

---

## Contributing

Found an issue or want to add an example? Please open an issue or PR on GitHub.

## License

All examples are provided under the same license as aixgo.
