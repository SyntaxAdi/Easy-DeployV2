import os
import sys
import site
import importlib
import traceback
from time import sleep

# Ensure user site packages directory is included in sys.path
try:
    user_site = site.getusersitepackages()
    if user_site and user_site not in sys.path:
        site.addsitedir(user_site)
except Exception:
    pass

EasyDeploy = r"""
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█                                    █
█      𝗘 𝗔 𝗦 𝗬 𝗗 𝗘 𝗣 𝗟 𝗢 𝗬  𝗩 𝟮       █
█                                    █
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
"""


def spinner(x):
    if x == "tele":
        print("Checking if Telethon is installed...")
    else:
        print("Checking if Pyrogram is installed...")
    for _ in range(3):
        for frame in r"-\|/-\|/":
            print("\b", frame, sep="", end="", flush=True)
            sleep(0.1)


def clear_screen():
    if os.name == "posix":
        os.system("clear")
    else:
        # for windows platform
        os.system("cls")


def stop_with_error(msg):
    print(f"\n[!] {msg}")
    input("\nPress Enter to continue...")
    clear_screen()
    exit(1)


def get_api_id_and_hash():
    print(
        "Get your API ID and API HASH from my.telegram.org to proceed.\n\n",
    )
    try:
        API_ID = int(input("Please enter your API ID: "))
    except ValueError:
        stop_with_error("APP ID must be an integer.")
    API_HASH = input("Please enter your API HASH: ").strip()
    if not API_HASH:
        stop_with_error("API HASH must not be empty.")
    return API_ID, API_HASH


def telethon_session():
    try:
        spinner("tele")
        import telethon
        x = "\bFound an existing installation of Telethon...\nSuccessfully Imported.\n\n"
    except ImportError:
        print("Installing Telethon...")
        os.system("pip3 install -U telethon --break-system-packages")
        try:
            user_site = site.getusersitepackages()
            if user_site and user_site not in sys.path:
                site.addsitedir(user_site)
        except Exception:
            pass
        importlib.invalidate_caches()
        import telethon
        x = "\bDone. Installed and imported Telethon."

    clear_screen()
    print(EasyDeploy)
    print(x)

    from telethon.errors.rpcerrorlist import (
        ApiIdInvalidError,
        PhoneNumberInvalidError,
        UserIsBotError,
    )
    from telethon.sessions import StringSession
    from telethon.sync import TelegramClient

    API_ID, API_HASH = get_api_id_and_hash()

    try:
        with TelegramClient(StringSession(), API_ID, API_HASH) as client:
            print("Generating a string session for •EasyDeploy•")
            try:
                client.send_message(
                    "me",
                    f"**EasyDeploy** `SESSION`:\n\n`{client.session.save()}`\n\n**Do not share this anywhere!**",
                )
                print(
                    "Your SESSION has been generated. Check your Telegram saved messages!"
                )
                return
            except UserIsBotError:
                print("You are trying to Generate Session for your Bot's Account?")
                print(f"Here is That!\n{client.session.save()}\n\n")
                print("NOTE: You can't use that as User Session..")
    except ApiIdInvalidError:
        stop_with_error("Your API ID/API HASH combination is invalid. Kindly recheck.")
    except ValueError:
        stop_with_error("API HASH must not be empty.")
    except PhoneNumberInvalidError:
        stop_with_error("The phone number is invalid.")
    except Exception as er:
        traceback.print_exc()
        stop_with_error(f"Unexpected Error Occurred while Creating Session:\n{er}")


def pyro_session():
    try:
        spinner("pyro")
        from pyrogram import Client
        x = "\bFound an existing installation of Pyrogram...\nSuccessfully Imported.\n\n"
    except ImportError:
        print("Installing Pyrogram...")
        os.system("pip3 install pyrogram tgcrypto --break-system-packages")
        try:
            user_site = site.getusersitepackages()
            if user_site and user_site not in sys.path:
                site.addsitedir(user_site)
        except Exception:
            pass
        importlib.invalidate_caches()
        from pyrogram import Client
        x = "\bDone. Installed and imported Pyrogram."

    clear_screen()
    print(EasyDeploy)
    print(x)

    # generate a session
    API_ID, API_HASH = get_api_id_and_hash()
    print("Enter phone number when asked.\n\n")
    try:
        with Client(name="easydeploy", api_id=API_ID, api_hash=API_HASH, in_memory=True) as pyro:
            ss = pyro.export_session_string()
            pyro.send_message(
                "me",
                f"`{ss}`\n\nAbove is your Pyrogram Session String for EasyDeploy. **DO NOT SHARE it.**",
            )
            print("Session has been sent to your saved messages!")
            return
    except Exception as er:
        traceback.print_exc()
        stop_with_error(f"Unexpected error occurred while creating session:\n{er}")


def main():
    clear_screen()
    print(EasyDeploy)
    try:
        type_of_ss = int(
            input(
                "\nEasyDeploy supports both telethon as well as pyrogram sessions.\n\nWhich session do you want to generate?\n1. Telethon Session.\n2. Pyrogram Session.\n\nEnter choice:  "
            )
        )
    except Exception as e:
        stop_with_error(f"Invalid input: {e}")

    if type_of_ss == 1:
        telethon_session()
    elif type_of_ss == 2:
        pyro_session()
    else:
        stop_with_error("Invalid choice entered.")

    x = input("\nRun again? (Y/n): ")
    if x.lower() in ["y", "yes"]:
        main()
    else:
        clear_screen()
        exit(0)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[!] Process interrupted by user.")
        input("\nPress Enter to continue...")
        clear_screen()
        exit(0)
    except Exception as e:
        traceback.print_exc()
        stop_with_error(f"Unhandled error: {e}")
