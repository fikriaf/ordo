# Analisis Struktur Backend & Testing - Solana Agent Kit

## 📋 Overview

Solana Agent Kit adalah toolkit open-source untuk menghubungkan AI agents dengan protokol Solana blockchain. Repository ini menggunakan arsitektur **monorepo** dengan **pnpm workspaces** dan **Turbo** untuk build orchestration.

---

## 🏗️ Arsitektur Backend

### 1. Struktur Monorepo

```
ordo-digital-assist/
├── packages/                    # Core packages
│   ├── core/                   # Core agent kit
│   ├── plugin-token/           # Token operations plugin
│   ├── plugin-nft/             # NFT operations plugin
│   ├── plugin-defi/            # DeFi operations plugin
│   ├── plugin-misc/            # Miscellaneous operations plugin
│   ├── plugin-blinks/          # Blinks operations plugin
│   └── adapter-mcp/            # MCP adapter for Claude Desktop
├── test/                       # Integration tests
├── examples/                   # Example implementations
└── docs/                       # Documentation
```

### 2. Build System

**Tools:**
- **pnpm**: Package manager dengan workspace support
- **Turbo**: Build orchestration untuk monorepo
- **tsup**: TypeScript bundler untuk build packages
- **TypeScript**: v5.7.2 dengan strict mode

**Build Configuration (turbo.json):**
```json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["packages/**"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"]
    }
  }
}
```

**Build Commands:**
```bash
pnpm build              # Build all packages
pnpm build:core         # Build core only
pnpm build:plugin-token # Build token plugin
pnpm build:plugin-defi  # Build defi plugin
```

---

## 📦 Core Package (`packages/core`)

### Struktur

```
packages/core/src/
├── agent/              # Main SolanaAgentKit class
├── types/              # TypeScript type definitions
│   ├── action.ts      # Action interface
│   └── wallet.ts      # Wallet interfaces
├── utils/              # Utility functions
│   ├── actionExecutor.ts
│   ├── keypairWallet.ts
│   ├── send_tx.ts
│   └── getMintInfo.ts
├── langchain/          # LangChain integration
├── vercel-ai/          # Vercel AI SDK integration
├── openai/             # OpenAI integration
├── claude/             # Claude integration
└── index.ts            # Main exports
```

### Main Class: SolanaAgentKit

```typescript
export class SolanaAgentKit<TPlugins = Record<string, never>> {
  public connection: Connection;
  public config: Config;
  public wallet: BaseWallet;
  public evmWallet?: EvmWallet;
  private plugins: Map<string, Plugin> = new Map();
  
  public methods: TPlugins = {} as TPlugins;
  public actions: Action[] = [];

  constructor(
    wallet: BaseWallet,
    rpc_url: string,
    config: Config,
    evmWallet?: EvmWallet,
  ) {
    this.connection = new Connection(rpc_url);
    this.wallet = wallet;
    this.config = config;
    this.evmWallet = evmWallet;
  }

  // Plugin system
  use<P extends Plugin>(plugin: P): SolanaAgentKit<TPlugins & PluginMethods<P>> {
    // Register plugin methods and actions
  }
}
```

### Action Interface

```typescript
export interface Action {
  name: string;                    // Unique action name
  similes: string[];               // Alternative trigger phrases
  description: string;             // What the action does
  examples: ActionExample[][];     // Input/output examples
  schema: z.ZodType<any>;         // Zod validation schema
  handler: Handler;                // Execution function
}

export type Handler = (
  agent: SolanaAgentKit,
  input: Record<string, any>,
) => Promise<Record<string, any>>;
```

### Dependencies

```json
{
  "@solana/web3.js": "^1.98.2",
  "@solana/spl-token": "^0.4.13",
  "@langchain/core": "^0.3.44",
  "@openai/agents": "^0.0.7",
  "ai": "^4.1.5",
  "bs58": "^6.0.0",
  "zod": "^3.24.1"
}
```

---

## 🔌 Plugin Architecture

### Plugin Interface

```typescript
interface Plugin {
  name: string;
  methods: Record<string, Function>;
  actions: Action[];
  initialize: (agent: SolanaAgentKit) => void;
}
```

### Plugin Structure Pattern

Setiap plugin mengikuti struktur yang konsisten:

```
plugin-{name}/src/
├── {protocol-1}/
│   ├── actions/        # AI-friendly action definitions
│   ├── tools/          # Core implementation functions
│   └── types/          # Type definitions
├── {protocol-2}/
│   ├── actions/
│   ├── tools/
│   └── types/
└── index.ts            # Plugin export
```

### Example: Token Plugin

**Protocols Integrated:**
- Jupiter (DEX aggregator)
- Light Protocol (ZK compression)
- Pump.fun (Token launcher)
- Pyth (Price feeds)
- Mayan (Cross-chain bridge)
- Rugcheck (Token security)
- Solutiofi (Token utilities)
- DexScreener (Market data)

**Plugin Export:**
```typescript
const TokenPlugin = {
  name: "token",
  
  methods: {
    // Jupiter
    fetchPrice,
    trade,
    stakeWithJup,
    createJupiterLimitOrder,
    // ... more methods
    
    // Light Protocol
    sendCompressedAirdrop,
    
    // Solana native
    transfer,
    get_balance,
    closeEmptyTokenAccounts,
    // ... more methods
  },
  
  actions: [
    transferAction,
    tradeAction,
    balanceAction,
    // ... more actions
  ],
  
  initialize: function() {
    // Initialize methods
  }
} satisfies Plugin;
```

### Example: DeFi Plugin

**Protocols Integrated:**
- Adrena (Perpetuals)
- Drift (Perpetuals, Vaults, Lending)
- Flash (Perpetuals)
- Lulo (Lending)
- Manifest (DEX)
- Meteora (AMM)
- OKX DEX (Aggregator)
- Openbook (DEX)
- Orca (AMM)
- Raydium (AMM)
- Sanctum (LST)
- Solayer (Staking)
- Voltr (Vaults)
- deBridge (Cross-chain)
- Fluxbeam (AMM)

**Total Methods:** 80+ DeFi operations

---

## 🎯 Action vs Tool Pattern

### Action (AI-Friendly Interface)

```typescript
// File: packages/plugin-token/src/solana/actions/transfer.ts
const transferAction: Action = {
  name: "TRANSFER",
  similes: ["send tokens", "transfer funds", "send money"],
  description: "Transfer tokens or SOL to another address",
  
  examples: [
    [{
      input: { to: "8x2d...", amount: 1 },
      output: { status: "success", transaction: "5Ufg..." },
      explanation: "Transfer 1 SOL to recipient"
    }]
  ],
  
  schema: z.object({
    to: z.string().min(32),
    amount: z.number().positive(),
    mint: z.string().optional(),
  }),
  
  handler: async (agent, input) => {
    const tx = await transfer(agent, new PublicKey(input.to), input.amount);
    return { status: "success", transaction: tx };
  }
};
```

### Tool (Core Implementation)

```typescript
// File: packages/plugin-token/src/solana/tools/transfer.ts
export async function transfer(
  agent: SolanaAgentKit,
  to: PublicKey,
  amount: number,
  mint?: PublicKey,
): Promise<string> {
  let transaction: Transaction;
  
  if (!mint) {
    // Transfer native SOL
    transaction = new Transaction().add(
      SystemProgram.transfer({
        fromPubkey: agent.wallet.publicKey,
        toPubkey: to,
        lamports: amount * LAMPORTS_PER_SOL,
      })
    );
  } else {
    // Transfer SPL token
    const fromAta = await getAssociatedTokenAddress(mint, agent.wallet.publicKey);
    const toAta = await getAssociatedTokenAddress(mint, to);
    
    // Create ATA if needed
    try {
      await getAccount(agent.connection, toAta);
    } catch {
      transaction.add(
        createAssociatedTokenAccountInstruction(
          agent.wallet.publicKey, toAta, to, mint
        )
      );
    }
    
    const mintInfo = await getMint(agent.connection, mint);
    const adjustedAmount = amount * Math.pow(10, mintInfo.decimals);
    
    transaction.add(
      createTransferInstruction(fromAta, toAta, agent.wallet.publicKey, adjustedAmount)
    );
  }
  
  return await signOrSendTX(agent, transaction.instructions);
}
```

**Key Differences:**
- **Action**: AI-friendly, includes examples, validation, natural language descriptions
- **Tool**: Pure implementation, focused on blockchain logic

---

## 🧪 Testing Structure

### Test Directory

```
test/
├── agentTests/              # AI agent integration tests
│   ├── vercel-ai.ts        # Vercel AI SDK test
│   ├── langchain.ts        # LangChain test
│   ├── openai.ts           # OpenAI test
│   └── claude.ts           # Claude test
├── programmaticTests/       # Direct method tests
│   └── index.ts
├── tools/                   # Specific tool tests
│   ├── okx_quote.test.ts
│   ├── okx_liquidity.test.ts
│   └── wormhole.ts
├── index.ts                 # Test entry point
├── utils.ts                 # Test utilities
└── package.json
```

### Test Types

#### 1. Agent Tests (Interactive)

Test AI agents dengan conversational interface:

```typescript
// test/agentTests/vercel-ai.ts
export default async function (agent: SolanaAgentKit) {
  const tools = createVercelAITools(agent, agent.actions);
  const openai = createOpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const messages: Message[] = [];

  while (true) {
    const prompt = await question("\nYou: ");
    if (prompt === "exit") break;

    messages.push({ content: prompt, role: "user" });

    const response = streamText({
      model: openai("gpt-4o"),
      tools,
      messages,
      system: `You are a helpful agent that can interact onchain...`,
      maxSteps: 5,
    });

    for await (const textPart of response.textStream) {
      process.stdout.write(textPart);
    }
  }
}
```

#### 2. Programmatic Tests

Test methods secara langsung:

```typescript
// test/programmaticTests/index.ts
export default async function (agentKit: SolanaAgentKit) {
  const agent = agentKit
    .use(TokenPlugin)
    .use(DefiPlugin);

  // Test token data fetch
  const tokenData = await agent.methods.getAsset(
    agent,
    "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
  );
  console.log("USDC Token Data:", tokenData);

  // Test balance
  const balance = await agent.methods.get_balance(agent);
  console.log("Balance:", balance);
}
```

#### 3. Tool-Specific Tests

Test individual tools dengan detailed scenarios:

```typescript
// test/tools/okx_quote.test.ts
async function testOkxDexQuote() {
  const agent = new SolanaAgentKit(wallet, rpcUrl, config);
  
  const solAddress = "So11111111111111111111111111111111111111112";
  const usdcAddress = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v";
  const amount = "10000000"; // 0.01 SOL

  const quote = await agent.getOkxQuote(
    solAddress,
    usdcAddress,
    amount,
    "0.5" // 0.5% slippage
  );

  console.log("Quote details:", JSON.stringify(quote.data[0], null, 2));
}
```

### Running Tests

```bash
# Run all tests
pnpm test

# Run specific test mode
npm run test
# Then choose:
# 1. agent - Interactive agent chat mode
# 2. programmatic - Direct method tests
```

### Test Configuration

```typescript
// test/index.ts
function validateEnvironment(): void {
  const requiredVars = [
    "OPENAI_API_KEY",
    "RPC_URL",
    "SOLANA_PRIVATE_KEY"
  ];
  
  requiredVars.forEach((varName) => {
    if (!process.env[varName]) {
      throw new Error(`Missing ${varName}`);
    }
  });
}
```

---

## 🔐 Environment Variables

### Core Variables

```bash
# AI Integration
OPENAI_API_KEY=

# Solana
RPC_URL=
SOLANA_PRIVATE_KEY=

# Jupiter (DEX)
JUPITER_REFERRAL_ACCOUNT=
JUPITER_FEE_BPS=

# Flash (Perpetuals)
FLASH_PRIVILEGE=referral|nft|none

# Lending
FLEXLEND_API_KEY=

# Infrastructure
HELIUS_API_KEY=

# Cross-chain
ETHEREUM_PRIVATE_KEY=
SUI_MNEMONIC=
APTOS_PRIVATE_KEY=
ETH_PRIVATE_KEY=

# Price Feeds
ALLORA_API_KEY=
ALLORA_API_URL=
ALLORA_NETWORK=testnet|mainnet

# AI Services
ELFA_AI_API_KEY=

# OKX DEX
OKX_API_KEY=
OKX_SECRET_KEY=
OKX_API_PASSPHRASE=
OKX_PROJECT_ID=
OKX_SOLANA_WALLET_ADDRESS=
OKX_SOLANA_PRIVATE_KEY=

# Monitoring
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT=https://api.smith.langchain.com
LANGSMITH_API_KEY=
LANGSMITH_PROJECT=
```

---

## 📊 Package Statistics

### Core Package
- **Size**: ~50KB (minified)
- **Dependencies**: 10 core dependencies
- **Exports**: 8 main exports
- **TypeScript**: Fully typed with strict mode

### Plugin Packages

| Plugin | Protocols | Methods | Actions | Size |
|--------|-----------|---------|---------|------|
| Token | 8 | 30+ | 20+ | ~200KB |
| DeFi | 17 | 80+ | 60+ | ~500KB |
| NFT | 4 | 15+ | 10+ | ~150KB |
| Misc | 5 | 20+ | 15+ | ~100KB |
| Blinks | 3 | 5+ | 5+ | ~50KB |

### Total Capabilities
- **60+ Solana Actions**
- **150+ Methods**
- **100+ Actions**
- **35+ Protocol Integrations**

---

## 🔄 Development Workflow

### 1. Setup

```bash
# Install dependencies
pnpm install

# Build all packages
pnpm build

# Run tests
pnpm test
```

### 2. Adding New Protocol

```bash
# 1. Create protocol directory in appropriate plugin
packages/plugin-{type}/src/{protocol}/
├── actions/
│   └── {action}.ts
├── tools/
│   └── {tool}.ts
└── types/
    └── {types}.ts

# 2. Implement tool
export async function myTool(
  agent: SolanaAgentKit,
  ...params
): Promise<Result> {
  // Implementation
}

# 3. Create action
const myAction: Action = {
  name: "MY_ACTION",
  similes: ["alternative names"],
  description: "What it does",
  examples: [[...]],
  schema: z.object({...}),
  handler: async (agent, input) => {
    return await myTool(agent, ...);
  }
};

# 4. Export in plugin index
import { myTool } from './{protocol}/tools';
import myAction from './{protocol}/actions';

const Plugin = {
  methods: { myTool, ... },
  actions: [myAction, ...],
  ...
};
```

### 3. Testing New Feature

```bash
# 1. Add test in test/programmaticTests/
const result = await agent.methods.myTool(agent, ...);
console.log("Result:", result);

# 2. Run test
pnpm test
# Choose: programmatic

# 3. Test with AI agent
pnpm test
# Choose: agent
# Choose: vercel-ai
# Chat: "Please use my new tool to..."
```

---

## 🎨 Code Quality

### Linting & Formatting

```bash
# Lint
pnpm lint

# Lint and fix
pnpm lint:fix

# Format
pnpm format
```

### Tools Used
- **Biome**: Fast linter and formatter
- **ESLint**: Additional linting rules
- **Prettier**: Code formatting
- **Husky**: Git hooks
- **lint-staged**: Pre-commit linting

---

## 📚 AI Framework Integrations

### 1. Vercel AI SDK

```typescript
import { createVercelAITools } from "solana-agent-kit";

const tools = createVercelAITools(agent, agent.actions);
const response = streamText({
  model: openai("gpt-4o"),
  tools,
  messages,
});
```

### 2. LangChain

```typescript
import { createLangchainTools } from "solana-agent-kit";

const tools = createLangchainTools(agent, agent.actions);
const executor = AgentExecutor.fromAgentAndTools({
  agent,
  tools,
});
```

### 3. OpenAI Agents

```typescript
import { createOpenAITools } from "solana-agent-kit";

const tools = createOpenAITools(agent, agent.actions);
const agent = new Agent({
  model: "gpt-4o",
  tools,
});
```

### 4. Claude (Anthropic)

```typescript
import { createClaudeTools } from "solana-agent-kit";

const tools = createClaudeTools(agent, agent.actions);
```

---

## 🚀 Deployment & Publishing

### Version Management

```bash
# Create changeset
pnpm changeset

# Version packages
pnpm version-packages

# Publish to npm
pnpm publish-packages
```

### Package Publishing

All packages are published to npm:
- `solana-agent-kit` (core)
- `@solana-agent-kit/plugin-token`
- `@solana-agent-kit/plugin-nft`
- `@solana-agent-kit/plugin-defi`
- `@solana-agent-kit/plugin-misc`
- `@solana-agent-kit/plugin-blinks`
- `@solana-agent-kit/adapter-mcp`

---

## 🔍 Key Insights

### Strengths

1. **Modular Architecture**: Plugin system memungkinkan extensibility
2. **Type Safety**: Full TypeScript dengan strict mode
3. **AI-First Design**: Actions dirancang untuk AI consumption
4. **Multi-Framework**: Support untuk berbagai AI frameworks
5. **Comprehensive**: 35+ protocol integrations
6. **Well-Tested**: Multiple testing strategies
7. **Monorepo**: Efficient development dengan shared dependencies

### Areas for Improvement

1. **Testing Coverage**: Tidak ada unit tests formal (Jest/Vitest)
2. **Documentation**: Inline documentation bisa lebih lengkap
3. **Error Handling**: Perlu standardisasi error handling
4. **Monitoring**: Belum ada built-in monitoring/observability
5. **Rate Limiting**: Tidak ada rate limiting untuk RPC calls
6. **Caching**: Tidak ada caching layer untuk repeated calls

---

## 📝 Kesimpulan

Solana Agent Kit adalah toolkit yang sangat comprehensive dengan:

- **Arsitektur yang solid**: Monorepo dengan plugin system
- **Integrasi luas**: 35+ protokol Solana
- **AI-friendly**: Dirancang khusus untuk AI agents
- **Multi-framework**: Support berbagai AI frameworks
- **Production-ready**: Sudah digunakan di production

Repository ini cocok untuk:
- Building AI agents untuk Solana
- Automating DeFi operations
- Creating trading bots
- Building blockchain applications dengan AI

**Tech Stack:**
- TypeScript + Solana Web3.js
- pnpm + Turbo (monorepo)
- Zod (validation)
- Multiple AI SDKs (Vercel AI, LangChain, OpenAI, Claude)
