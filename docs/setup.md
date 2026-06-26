# Setup

## Telegram Notifications (Optional)

1. Create a bot via [@BotFather](https://t.me/BotFather), copy the token
2. Get your chat ID: `https://api.telegram.org/botYOUR_TOKEN/getUpdates`
3. Add to repo → **Settings → Secrets → Actions**:

| Secret | Value |
|--------|-------|
| `TELEGRAM_BOT_TOKEN` | your bot token |
| `TELEGRAM_CHAT_ID` | your chat ID |

---

## Running a Build

Actions tab → **Build Kernels — AIO** → **Run workflow**

**Inputs:**

| Input | Options | Default |
|-------|---------|---------|
| `ZIP packaging` | `per-variant` · `aio` · `both` | `per-variant` |
| `Build type` | `stable` · `testing` | `stable` |

**Variants built per run:** Vili-Ksun · Vili-SukiSU · Vili-NoKSU

> `testing` builds append `-testing` to the ZIP name and mark the GitHub release as pre-release.
