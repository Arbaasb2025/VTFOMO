# VT FOMO

CS 3714 – Final Team Project  
Virginia Tech – Fall 2026

## 1. How to Open and Run the Project

1. Download the submitted ZIP file.
2. Extract the ZIP file to a folder on your Mac.
3. Open the extracted folder and locate `VTFomo.xcodeproj`.
4. Double-click `VTFomo.xcodeproj` to open the project in Xcode.
5. Select the **VTFomo** scheme.
6. Select an iPhone or iPad simulator running iOS 26.5 or later.
7. Press **Command + R** to build and run the application.

The project is configured to run using its existing Team and Bundle Identifier settings. No manual changes should be needed.

Sample data is loaded automatically when the app launches.

## 2. How to Log In

The app includes demo accounts to make testing easier.

1. Open the application.
2. Select **Already part of it? Sign in**.
3. Select **Sign-in help & demo accounts**.
4. Tap **Explore demo accounts**.
5. Choose an account to automatically fill in its login details.
6. Tap **Log In**.

You can switch between accounts by logging out through the Profile screen.

## 3. User Roles

VT FOMO includes different account roles with different permissions.

**Student**
- Browse and search campus events.
- Filter events by category, date, and residence hall.
- View event locations on the campus map.
- Save events and set reminders.
- View event details, weather, and walking information.

**Student Leader**
- Access student features.
- Request organizer permission for a residence hall.
- Create events after receiving approval.
- Manage events within the permitted residence hall.
- Edit or delete their own events.

**Campus Organizer**
- Create and publish campus events.
- Add event details, locations, and photos.
- Edit and delete their own events.
- View event save counts and manage published events.

**Area Coordinator**
- Review organizer requests.
- Approve or decline requests for assigned residence halls.
- Revoke previously granted permissions.
- Manage organizer access within their assigned area.

**Administrator**
- Manage coordinator assignments.
- Moderate events.
- Access administrative management features.

## 4. Main Application Features

**Events:** Browse upcoming campus activities, search events, and apply filters.

**Map:** View event locations using MapKit and access walking directions.

**Saved:** Save events, remove saved events, and schedule reminders.

**Profile:** Manage the account, organizer requests, and organizer events.

**Event Creation:** Approved organizers can add event information, choose locations, upload photos, and select event visibility.

**Organizer Dashboard:** Organizers can view upcoming and past events, edit or delete their events, and check save counts.

**Face ID:** Returning users can use biometric authentication when supported, with password login available as a fallback.

**Weather:** Event details include weather information when forecast data is available.

## 5. iPhone and iPad

VT FOMO supports both iPhone and iPad.

On iPhone, users navigate between the main screens using the app's navigation interface.

On iPad, the wider layout can display the event list and campus map side by side. Saved events and Profile are also accessible from the map toolbar.

## 6. Testing the Application

To test the main functionality:

1. Log in as a Student and explore the Events and Map screens.
2. Save an event and check the Saved screen.
3. Open event details to view weather and location information.
4. Sign in as an Area Coordinator and approve a pending organizer request.
5. Sign in as the approved Student Leader and create an event.
6. Edit or delete an event through the organizer dashboard.
7. Test the application on both an iPhone and iPad simulator.

For the organizer approval demonstration, use the same simulator when switching accounts.

To run the project's automated tests, select a simulator in Xcode and press **Command + U**.

## 7. Known Issues and Limitations

- The app uses local SwiftData storage, so account and event changes do not sync between different devices or simulators.
- Walking directions require location permission and an available device location.
- Weather forecasts require network access and are limited to supported forecast dates.
- Event reminders require notification permission.
- Face ID requires a compatible device or simulator configuration.

## 8. About VT FOMO

VT FOMO was developed to make it easier for Virginia Tech students to discover campus activities and events.

The application combines event discovery, interactive maps, reminders, weather information, and organizer management in one place.

The project was built using Swift, SwiftUI, and Xcode, with support for both iPhone and iPad.
