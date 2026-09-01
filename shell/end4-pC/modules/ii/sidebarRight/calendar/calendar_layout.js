// Monday is the first day of the week. Keep the desktop surface in
// Traditional Chinese even though the process locale is English.
const weekDays = [
    { day: '一', today: 0 },
    { day: '二', today: 0 },
    { day: '三', today: 0 },
    { day: '四', today: 0 },
    { day: '五', today: 0 },
    { day: '六', today: 0 },
    { day: '日', today: 0 },
]

function dateKey(dateObject) {
    const year = dateObject.getFullYear();
    const month = String(dateObject.getMonth() + 1).padStart(2, '0');
    const day = String(dateObject.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

function getDateInXMonthsTime(x) {
    var currentDate = new Date(); // Get the current date
    if (x == 0) return currentDate; // If x is 0, return the current date

    var targetMonth = currentDate.getMonth() + x; // Calculate the target month
    var targetYear = currentDate.getFullYear(); // Get the current year

    // Adjust the year and month if necessary
    targetYear += Math.floor(targetMonth / 12);
    targetMonth = (targetMonth % 12 + 12) % 12;

    // Create a new date object with the target year and month
    var targetDate = new Date(targetYear, targetMonth, 1);

    // Set the day to the last day of the month to get the desired date
    // targetDate.setDate(0);

    return targetDate;
}

function getCalendarLayout(dateObject, highlight) {
    if (!dateObject) dateObject = new Date();
    const year = dateObject.getFullYear();
    const monthIndex = dateObject.getMonth();
    const firstOfMonth = new Date(year, monthIndex, 1);
    const mondayOffset = (firstOfMonth.getDay() + 6) % 7;
    const todayKey = dateKey(new Date());
    const calendar = [...Array(6)].map(() => Array(7));

    for (let cellIndex = 0; cellIndex < 42; ++cellIndex) {
        // Calendar-field construction stays correct over daylight-saving
        // boundaries; adding fixed 24-hour millisecond chunks does not.
        const cellDate = new Date(year, monthIndex, 1 - mondayOffset + cellIndex);
        const key = dateKey(cellDate);
        const inCurrentMonth = cellDate.getMonth() === monthIndex;
        calendar[Math.floor(cellIndex / 7)][cellIndex % 7] = {
            "day": cellDate.getDate(),
            "dateKey": key,
            "inCurrentMonth": inCurrentMonth,
            "today": highlight && key === todayKey ? 1 : (inCurrentMonth ? 0 : -1)
        };
    }
    return calendar;
}
