import discord
from discord.ui import Button, View
import os
import subprocess
import requests
import tempfile
import sys
import json
from pathlib import Path

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

# Settings storage
SETTINGS_FILE = Path("bot_settings.json")

# Default settings for each user
DEFAULT_SETTINGS = {
    "hookOp": False,
    "explore_funcs": True,
    "spyexeconly": False,
    "no_string_limit": False,
    "minifier": False,
    "comments": True,
    "ui_detection": False,
    "notify_scamblox": False,
    "constant_collection": False,
    "duplicate_searcher": False,
    "neverNester": False
}

SETTING_DESCRIPTIONS = {
    "hookOp": "Hook operations (repeat, while, if, comparisons)",
    "explore_funcs": "Show full function bodies",
    "spyexeconly": "Only spy executor variables",
    "no_string_limit": "No string truncation",
    "minifier": "Minify/inline output",
    "comments": "Show helpful comments",
    "ui_detection": "Detect UI libraries [EXPERIMENTAL]",
    "notify_scamblox": "Notify scam detection (Premium only)",
    "constant_collection": "Collect all strings",
    "duplicate_searcher": "Search for duplicate files",
    "neverNester": "Prevent nested if checks"
}

def load_settings():
    """Load settings from file"""
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, 'r') as f:
                return json.load(f)
        except:
            return {}
    return {}

def save_settings(settings):
    """Save settings to file"""
    with open(SETTINGS_FILE, 'w') as f:
        json.dump(settings, f, indent=2)

def get_user_settings(user_id):
    """Get settings for a specific user"""
    all_settings = load_settings()
    user_id_str = str(user_id)
    if user_id_str not in all_settings:
        all_settings[user_id_str] = DEFAULT_SETTINGS.copy()
        save_settings(all_settings)
    return all_settings[user_id_str]

def update_user_setting(user_id, setting_name, value):
    """Update a specific setting for a user"""
    all_settings = load_settings()
    user_id_str = str(user_id)
    if user_id_str not in all_settings:
        all_settings[user_id_str] = DEFAULT_SETTINGS.copy()
    all_settings[user_id_str][setting_name] = value
    save_settings(all_settings)

class SettingsView(View):
    def __init__(self, user_id, settings):
        super().__init__(timeout=300)  # 5 minute timeout
        self.user_id = user_id
        self.settings = settings
        self.create_buttons()
    
    def create_buttons(self):
        """Create toggle buttons for all settings"""
        self.clear_items()
        
        for setting_name, description in SETTING_DESCRIPTIONS.items():
            is_enabled = self.settings.get(setting_name, False)
            button = Button(
                label=f"{'✅' if is_enabled else '❌'} {setting_name}",
                style=discord.ButtonStyle.success if is_enabled else discord.ButtonStyle.secondary,
                custom_id=setting_name
            )
            button.callback = self.create_callback(setting_name)
            self.add_item(button)
    
    def create_callback(self, setting_name):
        async def callback(interaction: discord.Interaction):
            if interaction.user.id != self.user_id:
                await interaction.response.send_message("❌ These are not your settings!", ephemeral=True)
                return
            
            # Toggle the setting
            current_value = self.settings.get(setting_name, False)
            new_value = not current_value
            update_user_setting(self.user_id, setting_name, new_value)
            self.settings[setting_name] = new_value
            
            # Recreate buttons with new state
            self.create_buttons()
            
            # Update the message
            embed = create_settings_embed(self.settings)
            await interaction.response.edit_message(embed=embed, view=self)
        
        return callback

def create_settings_embed(settings):
    """Create an embed showing current settings"""
    embed = discord.Embed(
        title="⚙️ Script Logger Settings",
        description="Click buttons below to toggle settings on/off",
        color=discord.Color.blue()
    )
    
    for setting_name, description in SETTING_DESCRIPTIONS.items():
        is_enabled = settings.get(setting_name, False)
        status = "✅ Enabled" if is_enabled else "❌ Disabled"
        embed.add_field(
            name=f"{setting_name}",
            value=f"{description}\n**Status:** {status}",
            inline=False
        )
    
    return embed

@client.event
async def on_ready():
    print(f'We have logged in as {client.user}')

@client.event
async def on_message(message):
    if message.author == client.user:
        return

    # Settings command
    if message.content.startswith('!settings'):
        user_settings = get_user_settings(message.author.id)
        embed = create_settings_embed(user_settings)
        view = SettingsView(message.author.id, user_settings)
        await message.channel.send(embed=embed, view=view)
        return

    if message.content.startswith('!log'):
        content = message.content[4:].strip()
        
        code_to_run = ""
        
        # Check for attachments
        if message.attachments:
            for attachment in message.attachments:
                try:
                    response = requests.get(attachment.url)
                    code_to_run = response.text
                    break # Only process first attachment
                except Exception as e:
                    await message.channel.send(f"Error reading attachment: {e}")
                    return
        
        # Check for code blocks
        elif "```" in content:
            # Extract content between backticks
            start = content.find("```") + 3
            end = content.rfind("```")
            if start < end:
                # Check if language is specified
                first_line_end = content.find("\n", start)
                if first_line_end != -1 and first_line_end < end:
                    # Check if the first line is a language identifier (no spaces, alphanumeric)
                    lang_line = content[start:first_line_end].strip()
                    if lang_line and " " not in lang_line:
                        start = first_line_end + 1
                
                code_to_run = content[start:end].strip()
            else:
                code_to_run = content.strip()
        
        # Check for URL
        elif content.startswith("http"):
            try:
                response = requests.get(content)
                code_to_run = response.text
            except Exception as e:
                await message.channel.send(f"Error fetching URL: {e}")
                return
        
        # Plain text
        else:
            code_to_run = content

        if not code_to_run:
            await message.channel.send("Please provide code to log.")
            return

        # Run in sandbox
        try:
            # Get user settings
            user_settings = get_user_settings(message.author.id)
            
            # Create temp file
            with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as tmp:
                tmp.write(code_to_run)
                tmp_path = tmp.name
            
            # Determine lune executable
            lune_exec = "lune"
            if os.path.exists("lune.exe"):
                lune_exec = os.path.abspath("lune.exe")
            elif os.path.exists("lune"):
                lune_exec = os.path.abspath("lune")
            
            # Run lune with advanced code reconstructor
            # We assume we are in the root directory
            logger_path = os.path.join("src", "code_reconstructor_advanced.lua")
            
            # Build command with settings as arguments
            cmd = [lune_exec, "run", logger_path, tmp_path]
            
            # Add settings as environment variables (easier for Lua to parse)
            env = os.environ.copy()
            for setting, value in user_settings.items():
                env[f"SETTING_{setting.upper()}"] = "1" if value else "0"
            
            print(f"Running command: {cmd}")
            print(f"Settings: {user_settings}")
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, env=env)
            
            os.remove(tmp_path)
            
            output = result.stdout
            if result.stderr:
                output += "\n-- STDERR --\n" + result.stderr
            
            if not output:
                output = "-- No output --"

            # Always send as .lua file for valid Lua code
            with tempfile.NamedTemporaryFile(mode='w', suffix='.lua', delete=False, encoding='utf-8') as log_file:
                log_file.write(output)
                log_file_path = log_file.name
            
            await message.channel.send("✅ Reconstructed code (executable Lua):", file=discord.File(log_file_path, "reconstructed.lua"))
            os.remove(log_file_path)

        except subprocess.TimeoutExpired:
            await message.channel.send("Execution timed out (10s limit).")
        except Exception as e:
            await message.channel.send(f"An error occurred: {e}")

if __name__ == "__main__":
    token = os.environ.get('DISCORD_TOKEN')
    if not token:
        print("Error: DISCORD_TOKEN environment variable not set.")
        sys.exit(1)
    client.run(token)
