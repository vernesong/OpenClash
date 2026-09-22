#!/bin/sh

START_LOG="/tmp/openclash_start.log"
LOG_FILE="/tmp/openclash.log"
		
LOG_OUT()
{
	if [ -n "${1}" ]; then
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Info] ${1}" >> $START_LOG
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Info] ${1}" >> $LOG_FILE
	fi
}

LOG_TIP()
{
	if [ -n "${1}" ]; then
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Tip] ${1}" >> $START_LOG
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Tip] ${1}" >> $LOG_FILE
	fi
}

LOG_WARN()
{
	if [ -n "${1}" ]; then
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Warning] ${1}" >> $START_LOG
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Warning] ${1}" >> $LOG_FILE
	fi
}

LOG_ERROR()
{
	if [ -n "${1}" ]; then
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Error] ${1}" >> $START_LOG
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Error] ${1}" >> $LOG_FILE
	fi
}

LOG_INFO()
{
	if [ -n "${1}" ]; then
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Info] ${1}" >> $LOG_FILE
	fi
}

LOG_WATCHDOG()
{
	if [ -n "${1}" ]; then
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") [Watchdog] ${1}" >> $LOG_FILE
	fi
}
