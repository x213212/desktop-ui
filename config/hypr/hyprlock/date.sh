#!/bin/sh

# Locale-independent Traditional Chinese date for the lock screen.
stamp=$(date '+%Y 年 %-m 月 %-d 日|%u') || exit 1
weekday_number=${stamp##*|}
calendar_date=${stamp%|*}

case "$weekday_number" in
    1) weekday=星期一 ;;
    2) weekday=星期二 ;;
    3) weekday=星期三 ;;
    4) weekday=星期四 ;;
    5) weekday=星期五 ;;
    6) weekday=星期六 ;;
    7) weekday=星期日 ;;
    *) weekday= ;;
esac

printf '%s　%s\n' "$calendar_date" "$weekday"
