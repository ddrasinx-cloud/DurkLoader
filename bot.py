import discord
from discord import app_commands
from discord.ext import commands
import aiohttp
import json
import os
import hashlib
import random
import string
import base64
from datetime import datetime, timezone

# ── CONFIG ──────────────────────────────────────────────
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO = "ddrasinx-cloud/DurkLoader"
KEYS_PATH = "keys.json"
SALT = "Apex1.0_X7k9m2pQ"

COLORS = {
    "green":   discord.Color.from_str("#4CAF50"),
    "red":     discord.Color.from_str("#E53935"),
    "blue":    discord.Color.from_str("#2196F3"),
    "orange":  discord.Color.from_str("#FF9800"),
    "purple":  discord.Color.from_str("#9C27B0"),
    "dark":    discord.Color.from_str("#0F0E16"),
}

# ── HELPERS ─────────────────────────────────────────────

def generate_key() -> str:
    return "".join(random.choices(string.ascii_letters + string.digits, k=24))

def sign_entry(entry: dict) -> dict:
    payload = json.dumps(entry, sort_keys=True, separators=(",", ":"))
    entry["sig"] = hashlib.sha256(f"{payload}:{SALT}".encode()).hexdigest()
    return entry

def parse_duration(text: str) -> int:
    import re
    n = int(re.search(r"\d+", text).group()) if re.search(r"\d+", text) else 30
    if "h" in text:   return n * 3600
    if "d" in text:   return n * 86400
    if "mo" in text:  return n * 2592000
    if "m" in text:   return n * 60
    return n * 86400

def format_duration(seconds: int) -> str:
    if seconds >= 2592000:   return f"{seconds // 2592000}mo"
    if seconds >= 86400:     return f"{seconds // 86400}d"
    if seconds >= 3600:      return f"{seconds // 3600}h"
    return f"{seconds // 60}m"

async def github_get(path: str) -> dict | None:
    url = f"https://api.github.com/repos/{REPO}/contents/{path}"
    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
    async with aiohttp.ClientSession() as sess:
        async with sess.get(url, headers=headers) as resp:
            if resp.status == 200:
                data = await resp.json()
                content = base64.b64decode(data["content"]).decode()
                return json.loads(content), data["sha"]
    return None, None

async def github_put(path: str, content: str, sha: str, message: str) -> bool:
    url = f"https://api.github.com/repos/{REPO}/contents/{path}"
    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}", "Content-Type": "application/json"}
    payload = {"message": message, "content": base64.b64encode(content.encode()).decode(), "sha": sha}
    async with aiohttp.ClientSession() as sess:
        async with sess.put(url, headers=headers, json=payload, timeout=aiohttp.ClientTimeout(total=30)) as resp:
            return resp.status in (200, 201)

async def load_keys():
    data, _ = await github_get(KEYS_PATH)
    return data or {}

async def save_keys(keys: dict, sha: str, msg: str = "Update keys") -> bool:
    return await github_put(KEYS_PATH, json.dumps(keys, indent=2), sha, msg)

def make_key_embed(key: str, entry: dict) -> discord.Embed:
    status = "Frozen \u274c" if entry.get("frozen") else "Active \u2705"
    expires = datetime.fromtimestamp(entry.get("expires", 0), tz=timezone.utc)
    created = datetime.fromtimestamp(entry.get("created", 0), tz=timezone.utc)
    remaining = expires - datetime.now(timezone.utc)
    e = discord.Embed(title=f"Key: `{key}`", color=COLORS["red"] if entry.get("frozen") else COLORS["green"])
    e.add_field(name="Status", value=status)
    e.add_field(name="Duration", value=format_duration(entry.get("duration", 0)))
    e.add_field(name="Created", value=f"<t:{entry.get('created',0)}:R>")
    e.add_field(name="Expires", value=f"<t:{entry.get('expires',0)}:R>")
    e.add_field(name="Remaining", value=f"{remaining.days}d {remaining.seconds//3600}h" if remaining.days >= 0 else "Expired")
    e.add_field(name="HWID", value=f"`{entry.get('hwid','Not bound')}`" if entry.get("hwid") else "Not bound")
    e.set_footer(text="Apex Software")
    return e

# ── BOT ─────────────────────────────────────────────────

class ApexPanel(commands.Bot):
    def __init__(self):
        intents = discord.Intents.default()
        intents.message_content = True
        super().__init__(command_prefix="!", intents=intents)

    async def setup_hook(self):
        await self.tree.sync()

    async def on_ready(self):
        print(f"[Apex Panel] Logged in as {self.user}")

bot = ApexPanel()

# ── COMMANDS ────────────────────────────────────────────

@bot.tree.command(name="setup", description="Auto-create APEX channels, webhooks, and return URLs")
@app_commands.checks.has_permissions(administrator=True)
async def setup(interaction: discord.Interaction):
    await interaction.response.defer(ephemeral=True)
    guild = interaction.guild

    # Check / create category
    cat = discord.utils.get(guild.categories, name="APEX SECURITY")
    if not cat:
        cat = await guild.create_category("APEX SECURITY", reason="Apex bot setup")

    channel_defs = {
        "login-logs":   "Login notifications",
        "hwid-logs":    "HWID binding logs",
        "key-logs":     "Key usage logs",
        "control-panel":"Bot command output",
    }

    webhooks = {}
    for ch_name, topic in channel_defs.items():
        existing = discord.utils.get(guild.channels, name=ch_name, category=cat)
        if not existing:
            existing = await guild.create_text_channel(ch_name, category=cat, topic=topic)
        wh = await existing.create_webhook(name=f"Apex {ch_name}")
        webhooks[ch_name] = wh.url

    embed = discord.Embed(
        title="Apex Security \u2014 Auto-Setup Complete",
        description="Channels and webhooks created below. Copy these URLs into your script config.",
        color=COLORS["green"],
    )
    embed.add_field(name="\U0001f4c1 Category", value=cat.name, inline=False)
    for name, url in webhooks.items():
        embed.add_field(name=f"#{name}", value=f"`{url}`", inline=False)
    embed.set_footer(text="Keep these URLs private \u2014 anyone with them can post to your channels")

    # Send panel DM
    try:
        await interaction.user.send(embed=embed)
        await interaction.followup.send("Check your DMs for the setup details!", ephemeral=True)
    except:
        await interaction.followup.send(embed=embed, ephemeral=True)

# ── KEY MANAGEMENT ──────────────────────────────────────

key_group = app_commands.Group(name="key", description="Key management commands")

@key_group.command(name="generate", description="Generate a new license key")
@app_commands.describe(duration="Key duration (e.g. 30d, 24h, 1mo, 60m)")
async def key_generate(interaction: discord.Interaction, duration: str):
    await interaction.response.defer()
    keys, sha = await github_get(KEYS_PATH)
    if keys is None:
        return await interaction.followup.send("Failed to read keys from GitHub.", ephemeral=True)

    dur = parse_duration(duration)
    now = int(datetime.now().timestamp())
    key = generate_key()

    entry = sign_entry({
        "created": now,
        "expires": now + dur,
        "duration": dur,
        "frozen": False,
        "hwid": "",
    })
    keys[key] = entry

    if await save_keys(keys, sha, f"Generate key {key}"):
        embed = make_key_embed(key, entry)
        embed.title = "Key Generated"
        await interaction.followup.send(embed=embed)
    else:
        await interaction.followup.send("Failed to save key to GitHub.", ephemeral=True)

@key_group.command(name="freeze", description="Freeze a key")
@app_commands.describe(key="The license key to freeze")
async def key_freeze(interaction: discord.Interaction, key: str):
    await interaction.response.defer()
    keys, sha = await github_get(KEYS_PATH)
    if keys is None or key not in keys:
        return await interaction.followup.send("Key not found.", ephemeral=True)
    keys[key]["frozen"] = True
    if await save_keys(keys, sha, f"Freeze key {key}"):
        await interaction.followup.send(embed=make_key_embed(key, keys[key]))

@key_group.command(name="unfreeze", description="Unfreeze a key")
@app_commands.describe(key="The license key to unfreeze")
async def key_unfreeze(interaction: discord.Interaction, key: str):
    await interaction.response.defer()
    keys, sha = await github_get(KEYS_PATH)
    if keys is None or key not in keys:
        return await interaction.followup.send("Key not found.", ephemeral=True)
    keys[key]["frozen"] = False
    if await save_keys(keys, sha, f"Unfreeze key {key}"):
        await interaction.followup.send(embed=make_key_embed(key, keys[key]))

@key_group.command(name="delete", description="Delete a key")
@app_commands.describe(key="The license key to delete")
async def key_delete(interaction: discord.Interaction, key: str):
    await interaction.response.defer()
    keys, sha = await github_get(KEYS_PATH)
    if keys is None or key not in keys:
        return await interaction.followup.send("Key not found.", ephemeral=True)
    del keys[key]
    if await save_keys(keys, sha, f"Delete key {key}"):
        await interaction.followup.send(f"Key `{key}` deleted.", ephemeral=True)

@key_group.command(name="info", description="Show key info")
@app_commands.describe(key="The license key")
async def key_info(interaction: discord.Interaction, key: str):
    await interaction.response.defer()
    keys, _ = await github_get(KEYS_PATH)
    if keys is None or key not in keys:
        return await interaction.followup.send("Key not found.", ephemeral=True)
    await interaction.followup.send(embed=make_key_embed(key, keys[key]))

@key_group.command(name="list", description="List all keys (paginated)")
@app_commands.describe(page="Page number (default: 1)")
async def key_list(interaction: discord.Interaction, page: int = 1):
    await interaction.response.defer()
    keys, _ = await github_get(KEYS_PATH)
    if not keys:
        return await interaction.followup.send("No keys found.", ephemeral=True)

    per_page = 10
    items = list(keys.items())
    total_pages = max(1, (len(items) + per_page - 1) // per_page)
    page = max(1, min(page, total_pages))
    start = (page - 1) * per_page
    chunk = items[start:start + per_page]

    embed = discord.Embed(title=f"Keys \u2014 Page {page}/{total_pages}", color=COLORS["dark"])
    for k, v in chunk:
        status = "\u274c" if v.get("frozen") else "\u2705"
        hwid = f"`{v['hwid'][:12]}...`" if v.get("hwid") else "Unbound"
        embed.add_field(name=f"{status} `{k}`", value=f"HWID: {hwid}", inline=False)
    embed.set_footer(text=f"{len(items)} total keys")
    await interaction.followup.send(embed=embed)

@key_group.command(name="stats", description="Key statistics")
async def key_stats(interaction: discord.Interaction):
    await interaction.response.defer()
    keys, _ = await github_get(KEYS_PATH)
    if keys is None:
        return await interaction.followup.send("Failed to load keys.", ephemeral=True)

    total = len(keys)
    active = sum(1 for v in keys.values() if not v.get("frozen") and v.get("expires", 0) > datetime.now().timestamp())
    frozen = sum(1 for v in keys.values() if v.get("frozen"))
    expired = sum(1 for v in keys.values() if v.get("expires", 0) <= datetime.now().timestamp())
    bound = sum(1 for v in keys.values() if v.get("hwid"))

    embed = discord.Embed(title="Key Statistics", color=COLORS["purple"])
    embed.add_field(name="Total", value=str(total))
    embed.add_field(name="Active", value=str(active))
    embed.add_field(name="Frozen", value=str(frozen))
    embed.add_field(name="Expired", value=str(expired))
    embed.add_field(name="HWID Bound", value=str(bound))
    embed.add_field(name="Unbound", value=str(total - bound))
    embed.set_footer(text="Apex Software")
    await interaction.followup.send(embed=embed)

bot.tree.add_command(key_group)

# ── RUN ─────────────────────────────────────────────────

if __name__ == "__main__":
    token = os.getenv("DISCORD_TOKEN")
    if not token:
        print("ERROR: Set DISCORD_TOKEN environment variable")
        print("Example (Windows): set DISCORD_TOKEN=your_token_here")
        exit(1)
    bot.run(token)
