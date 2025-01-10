import asyncio
import json
import os

import requests
from bs4 import BeautifulSoup
from telegram import Bot
from dotenv import load_dotenv

load_dotenv()


def get_toto_prize():
    url = "https://online.singaporepools.com/en/lottery"
    response = requests.get(url)
    soup = BeautifulSoup(response.text, "html.parser")

    # Find all divs with data-component="Banner"
    banners = soup.find_all("div", {"data-component": "Banner"})

    # Iterate through them to find the one you need
    for banner in banners:
        data_prop_banner = banner.get("data-prop-banner")
        if data_prop_banner:
            # Parse the JSON
            banner_data = json.loads(data_prop_banner)

            # Check for specific conditions, e.g., jackpot > 1M or nid
            jackpot = banner_data.get("jackpot", 0)
            if jackpot > 0:  # Adjust condition as needed
                print(f"Found matching jackpot: SGD {jackpot:,}")
                return jackpot


async def send_notification():
    try:
        prize = get_toto_prize()
        if prize > 1_000_000:
            message = f"The upcoming TOTO prize is SGD {prize:,}! Don't miss out!"
            bot = Bot(token=os.environ["BOT_TOKEN"])
            await bot.send_message(chat_id=os.environ["CHAT_ID"], text=message)
            print("Message sent successfully")
    except Exception as e:
        print(f"Error: {e}")


async def get_chat_id():

    bot = Bot(token=os.environ["BOT_TOKEN"])
    updates = await bot.get_updates()

    for update in updates:
        print(update.message.chat.id)


if __name__ == "__main__":
    # asyncio.run(get_chat_id())
    asyncio.run(send_notification())
