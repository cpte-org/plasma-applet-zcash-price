/*
 *   Copyright (C) 2024 Zcash Price Applet Contributors
 *   SPDX-License-Identifier: GPL-3.0
 */

import QtQuick
import org.kde.plasma.configuration as PlasmaConfiguration

PlasmaConfiguration.ConfigModel {
    PlasmaConfiguration.ConfigCategory {
        name: i18n("General")
        icon: "preferences-system-windows"
        source: "config/configGeneral.qml"
    }
}
