# Progress Tracker

## Current Goal
Get rustdesk stack up

## Acceptance Criteria
- [x] I can connect to the RustDesk server using the docker relay server

## Details
The RustDesk stack is now running with the following services:
- hbbs (ID server) running on ports 31115-31118
- hbbr (relay server) running on ports 31117 and 31119

To connect, use the following settings in your RustDesk client:
- ID Server: rustdesk.example.com:31117
- Relay Server: rustdesk.example.com:31117
