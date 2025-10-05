import re
import asyncio
import json
import os

from selenium import webdriver
from tempfile import mkdtemp
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from telegram import Bot


def get_toto_jackpot():
    options = webdriver.ChromeOptions()
    service = webdriver.ChromeService("/opt/chromedriver")

    options.binary_location = "/opt/chrome/chrome"
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1280x1696")
    options.add_argument("--single-process")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-dev-tools")
    options.add_argument("--no-zygote")
    # options.add_argument(f"--user-data-dir={mkdtemp()}")
    # options.add_argument(f"--data-path={mkdtemp()}")
    # options.add_argument(f"--disk-cache-dir={mkdtemp()}")
    # options.add_argument("--remote-debugging-port=9222")

    chrome = webdriver.Chrome(options=options, service=service)
    chrome.get("https://online.singaporepools.com/en/lottery")

    # Wait for the main content to load
    try:
        jackpot_div = WebDriverWait(chrome, 60).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "div.slab.slab--jackpot"))
        )
        jackpot_amount = jackpot_div.find_element(
            By.CSS_SELECTOR, "span.slab__text--highlight"
        ).text

        numbers = re.findall(r"\d+", jackpot_amount)
        result = "".join(numbers)  # Join the extracted numbers
        return int(result)
    except Exception as e:
        print(f"Error: {e}")

    chrome.quit()


async def send_notification(prize):
    """
    Sends a notification via Telegram to all configured chat IDs if the prize exceeds the threshold.
    Supports multiple chat IDs separated by commas in the CHAT_ID environment variable.
    """
    try:
        if prize >= int(os.environ["PRIZE_THRESHOLD"]):
            message = f"The upcoming TOTO prize is SGD {prize:,}! Don't miss out!"
            bot = Bot(token=os.environ["BOT_TOKEN"])

            # Parse chat IDs from environment variable (supports comma-separated list)
            chat_ids_str = os.environ["CHAT_ID"]
            chat_ids = [chat_id.strip() for chat_id in chat_ids_str.split(",")]

            # Track success and failures
            successful_sends = []
            failed_sends = []

            # Send to each chat ID independently
            for chat_id in chat_ids:
                try:
                    await bot.send_message(chat_id=chat_id, text=message)
                    successful_sends.append(chat_id)
                    print(f"Message sent successfully to chat ID: {chat_id}")
                except Exception as chat_error:
                    failed_sends.append(chat_id)
                    print(f"Error sending message to chat ID {chat_id}: {chat_error}")

            # Summary logging
            if successful_sends:
                print(
                    f"Successfully sent to {len(successful_sends)} chat(s): {', '.join(successful_sends)}"
                )
            if failed_sends:
                print(
                    f"Failed to send to {len(failed_sends)} chat(s): {', '.join(failed_sends)}"
                )

    except Exception as e:
        print(f"Error sending message: {e}")


async def get_chat_id():
    from dotenv import load_dotenv

    load_dotenv()

    bot = Bot(token=os.environ["BOT_TOKEN"])
    updates = await bot.get_updates()

    for update in updates:
        if update.message:
            print(update.message.chat.id, update.message.chat.title)


def handler(event=None, context=None):
    """
    AWS Lambda entry point.
    """
    try:
        # Get the prize amount
        prize = get_toto_jackpot()
        print(f"Jackpot prize found: SGD {prize:,}")

        # Run the notification in an async loop
        asyncio.run(send_notification(prize))

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Notification processed successfully"}),
        }
    except Exception as e:
        print(f"Error in Lambda function: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}


if __name__ == "__main__":
    asyncio.run(get_chat_id())
