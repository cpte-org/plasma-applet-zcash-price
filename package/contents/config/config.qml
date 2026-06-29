/*
 *   Copyright (C) 2024 Zcash Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 */

import QtQuick
import org.kde.plasma.configuration as PlasmaConfiguration

PlasmaConfiguration.ConfigModel {
    PlasmaConfiguration.ConfigCategory {
        name: i18n("Coins")
        icon: "view-list-icons"
        source: "config/configGeneral.qml"
    }

    PlasmaConfiguration.ConfigCategory {
        name: i18n("Alarms")
        icon: "preferences-desktop-notification"
        source: "config/configAlarms.qml"
    }

    PlasmaConfiguration.ConfigCategory {
        name: i18n("Display")
        icon: "preferences-desktop-display"
        source: "config/configDisplay.qml"
    }
}
