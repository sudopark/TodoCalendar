//
//  Workspace.swift
//  TodoCalendar-developManifests
//
//  Created by 강준영 on 2023/12/16.
//

import ProjectDescription

let workspace = Workspace(name: "TodoCalendar", 
                          projects: [
                            "TodoCalendarApp",
                            "Domain",
                            "Repository",
                            "Presentations/CommonPresentation",
                            "Presentations/Scenes",
                            "Presentations/CalendarScenes",
                            "Presentations/EventDetailScene",
                            "Presentations/SettingScene",
                            "Supports/Extensions",
                            "Supports/UnitTestHelpKit",
                            "Supports/Common3rdParty",
                            "Supports/TestDoubles"
                          ])