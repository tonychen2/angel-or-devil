## Product Requirements Document: Angel or Devil (Working Title)
Author: Gemini
Date: September 1, 2025
Version: 1.0 (MVP)

1. Overview 📝
Angel or Devil is a simple, beautifully designed mobile journaling app for new parents. It aims to provide a low-effort, daily ritual to capture the emotional journey of raising a baby. By asking one simple question each day, the app helps parents record memories and reflect on the highs and lows, creating a keepsake calendar they can look back on. The MVP is designed for simplicity, with all data stored locally on the user's device, requiring no internet connection or user accounts.

2. Goals and Objectives 🎯
Primary Goal: Create an effortless and delightful daily habit for new parents to log their day.

User Objective: Provide a quick way to record the feeling of a day (the "angel or devil" dynamic) and optionally add more context, without the pressure of traditional journaling.

Product Objective: Launch a focused MVP to validate the core loop (daily prompt -> log -> calendar view) and gather user feedback for future features.

3. Target Audience 👥
The primary users are new parents, typically in the first 0-24 months of their child's life.

Characteristics: They are often sleep-deprived, time-poor, and emotionally overwhelmed. They experience a rollercoaster of joy, frustration, and love.

Needs: They need tools that are extremely simple, fast, and emotionally resonant. They value capturing memories but lack the time and energy for complex apps or physical journals.

4. MVP Feature Set & User Stories ✨
The MVP consists of three core components: the daily prompt, the logging action, and the calendar view.

F-01: Daily Logging Prompt
Description: A local notification is triggered daily to prompt the user to log their day.

User Story: "As a busy parent, I want to receive a gentle reminder each evening, so I don't forget to capture a thought from the day."

Requirements:

A local notification is scheduled to fire daily at 9:00 PM (21:00) local device time.

Notification Title: Angel Baby

Notification Body: How was your little one today?

Tapping the notification opens the app to the daily question screen.

F-02: Angel vs. Devil Input
Description: The primary screen after opening the app (via notification or icon) is the daily question.

User Story: "As a tired parent, I want to quickly tap an icon to summarize the day's vibe, so I can log my feelings in less than 5 seconds."

Requirements:

The screen displays a simple question: "Was your baby a little angel or a little devil today?"

Two clear, tappable choices are presented: an "Angel" icon and a "Devil" icon.

Once a choice is made, it is immediately saved, and the user is taken to the optional diary entry screen.

F-03: Optional Diary Entry
Description: After selecting an icon, the user has the option to add free-text notes.

User Story: "As a reflective parent, I want the option to write a few sentences about why the day was good or challenging, so I can remember the details later."

Requirements:

A simple text input field is presented with a prompt like "What's on your mind?"

A "Save" or "Done" button saves the entry, even if no text is typed in.

After saving, the user is taken to the Monthly Calendar View.

F-04: Monthly Calendar View
Description: The main screen of the app, displaying a history of the user's logs.

User Story: "As a sentimental parent, I want to see a monthly overview of our days, so I can look back and see patterns and memories at a glance."

Requirements:

Displays a standard monthly calendar grid.

For each day with an entry, the corresponding Angel or Devil icon is displayed on the calendar date.

Days with no entry are left blank.

The user can navigate to previous/next months.

Tapping on a day with an entry opens the "Day Detail View."

F-05: Day Detail View
Description: A view to see the full details of a past entry.

User Story: "As a curious parent, I want to be able to tap on a day in the calendar, so I can read the notes I wrote for that day."

Requirements:

This screen displays the date, the chosen Angel/Devil icon, and the full text of the diary entry.

User can still edit both the chosen icon and the text. A "save" button would be greyed out by default if no edit has been made.

After any edits, clicking on the "save" button automatically takes the user back to the Monthly Calendar View. Otherwise, user can also exit the Day Detail View via either the system-default "back" gesture or a left-pointing arrow on the top left corner.

5. Design & User Experience (UX) 🎨
Aesthetic: Clean, cute, and minimalist with a hand-drawn feel.

Color Palette: Soft, pastel colors (e.g., light yellows, baby blues, soft pinks, mint greens) to create a calming and gentle atmosphere.

Typography: A friendly, rounded sans-serif font that is easy to read.

Iconography: Custom-designed icons for "Angel" and "Devil" that are endearing and whimsical, not literal or negative. All UI elements (buttons, calendar) should feel soft and approachable.

User Flow: The core loop should be extremely simple:

User receives notification.

Taps notification -> App opens on the Question Screen.

User taps "Angel" or "Devil".

(Optional) User types in the Diary Screen and taps "Save".

User is navigated to the Monthly Calendar View.

6. Technical Requirements ⚙️
Platform: iOS and Android.

Architecture: 100% Client-Side.

There will be no backend server.

There will be no user accounts or login.

There will be no network calls. All logic and data resides on the device.

Data Storage: All data (daily choices, diary entries) must be stored locally on the user's phone. Use reliable local storage solutions like:

Flutter: Hive or sqflite.

Notifications: Must use the native local notification systems for iOS and Android, scheduled by the app.

7. Future Considerations (Post-MVP) 🚀
The following features are explicitly out of scope for the MVP but should be considered for future releases:

User-configurable notification time.

Custom motivational message after each selection.

Analytical insights (e.g., "You had 15 angel days and 5 devil days this month!"), either in the Monthly Calendar View or on a separate tab.

Ability to add photos to entries.

Tracking developmental milestones.

Data backup and restore functionality (e.g., via iCloud/Google Drive).

Multiple child profiles.

8. Success Metrics 📈
Retention: D7/D30 retention rate. Are new parents continuing to use the app after the first week/month?

Engagement:

Percentage of daily active users who complete the daily log.

Ratio of entries with text notes vs. icon-only entries.

Qualitative Feedback: Positive reviews and ratings on the App Store and Google Play Store, with specific mentions of ease of use and delightful design.