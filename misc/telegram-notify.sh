#!/usr/bin/env bash
notify() {
	chatid=your_chat_id                         # Your chat id
	token=your_bot_token                        # Your Bot's token from botfather
	default_message="Hello,I am up and running perfectly!"
# shellcheck disable=SC2198
	if [ -z "$@" ]
	then
		curl -s --data-urlencode "text=$default_message" "https://api.telegram.org/bot$token/sendMessage?chat_id=$chatid" > /dev/null
	else
		# shellcheck disable=SC2145
		curl -s --data-urlencode "text=$@" "https://api.telegram.org/bot$token/sendMessage?chat_id=$chatid" > /dev/null
	fi
}

alias notify=notify
