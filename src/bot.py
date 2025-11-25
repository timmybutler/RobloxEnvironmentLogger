import discord
import os
import subprocess
import requests
import tempfile
import sys

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

@client.event
async def on_ready():
    print(f'We have logged in as {client.user}')

@client.event
async def on_message(message):
    if message.author == client.user:
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
            
            # Run lune with ultimate environment logger
            # We assume we are in the root directory
            logger_path = os.path.join("src", "env_logger_ultimate.lua")
            
            cmd = [lune_exec, "run", logger_path, tmp_path]
            print(f"Running command: {cmd}")
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            
            os.remove(tmp_path)
            
            output = result.stdout
            if result.stderr:
                output += "\n-- STDERR --\n" + result.stderr
            
            if not output:
                output = "-- No output --"

            if len(output) > 1900:
                # Send as file
                with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8') as log_file:
                    log_file.write(output)
                    log_file_path = log_file.name
                
                await message.channel.send("Log output:", file=discord.File(log_file_path, "log.txt"))
                os.remove(log_file_path)
            else:
                await message.channel.send(f"```lua\n{output}\n```")

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
