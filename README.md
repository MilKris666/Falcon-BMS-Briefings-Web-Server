# Falcon-BMS-Briefings-Web-Server
This PowerShell script makes the Falcon BMS briefings available to all devices on the network via a browser. 
The script starts a simple web server on the Falcon BMS computer and automatically updates the latest Briefing.html.


How-To Setup:

    Enable PowerShell Script Execution Policy:
    Open PowerShell as Administrator and enter the following command:
    Set-ExecutionPolicy RemoteSigned

    Adjust the Falcon BMS Installation Path in the Script:
    Right-click the script and select Edit. Update the path in the script:
    Line 10:
    $BriefingFolder = "C:\Falcon BMS 4.37\User\Briefings"

    Enable HTML Briefings in the Falcon BMS Config:
    Open the Falcon Launcher and go to Config.
    Under GENERAL > BRIEFING/DEBRIEFING, check the following options:
        1. Briefing Output to File
        3. HTML Briefings

How to Run:

    Run the script by right-clicking it and selecting Run with PowerShell. 
    
    Keep the console window open or minimize it, don´t close it.
    In the Falcon Mission Scheduler, open a briefing and click Print. 
    This will generate an HTML file, and the script will start the web server.
    The script checks every 5 seconds for updated HTML files and refreshes the web server.

To view the briefing on your phone or tablet, open a browser and enter one of the following addresses:

    http://computername:8080
    http://IP-address:8080

Note:
If you print a new briefing in the Falcon Scheduler, you need to refresh the browser to see the updated content.
