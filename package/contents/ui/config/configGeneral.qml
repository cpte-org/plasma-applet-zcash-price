import QtQuick 2.1
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1

import ".."
import "../../code/zcash.js" as Zcash

Item {
	id: configGeneral
	Layout.fillWidth: true
	property string cfg_source: plasmoid.configuration.source
	property string cfg_currency: plasmoid.configuration.currency
	property string cfg_onClickAction: plasmoid.configuration.onClickAction
	property alias cfg_refreshRate: refreshRate.value
	property alias cfg_showIcon: showIcon.checked
	property alias cfg_showText: showText.checked
	property alias cfg_showDecimals: showDecimals.checked
	property alias cfg_showBackground: showBackground.checked
	property variant sourceList: { Zcash.getAllSources() }
	property variant currencyList: { Zcash.getAllCurrencies() }

	GridLayout {
		columns: 2
		
		Label {
			text: i18n("Source:")
		}
		
		ComboBox {
			id: source
			model: sourceList
			Layout.minimumWidth: theme.mSize(theme.defaultFont).width * 15
			onActivated: {
				cfg_source = source.textAt(index)
			}
			Component.onCompleted: {
				var sourceIndex = source.find(plasmoid.configuration.source)
				
				if(sourceIndex != -1) {
					source.currentIndex = sourceIndex
				}
			}
		}
		
		Label {
			text: i18n("Currency:")
		}
		
		ComboBox {
			id: currency
			model: currencyList
			Layout.minimumWidth: theme.mSize(theme.defaultFont).width * 15
			onActivated: {
				cfg_currency = currency.textAt(index)
			}
			Component.onCompleted: {
				var currencyIndex = currency.find(plasmoid.configuration.currency)
				
				if(currencyIndex != -1) {
					currency.currentIndex = currencyIndex
				}
			}
		}
		
		Label {
			text: i18n("Refresh rate:")
		}
		
		SpinBox {
			id: refreshRate
			suffix: i18n(" minutes")
			minimumValue: 1
		}
		
		Label {
			text: ""
		}
		
		CheckBox {
			id: showIcon
			text: i18n("Show icon")
			onClicked: {
				if(!this.checked) {
					showText.checked = true
					showText.enabled = false
				} else {
					showText.enabled = true
				}
			}
		}
		
		Label {
			text: ""
		}
		
		CheckBox {
			id: showText
			text: i18n("Show text (when disabled, the rate is visible on hover)")
			onClicked: {
				if(!this.checked) {
					showIcon.checked = true
					showIcon.enabled = false
				} else {
					showIcon.enabled = true
				}
			}
		}
		
		Label {
			text: ""
		}
		
		CheckBox {
			id: showDecimals
			text: i18n("Show decimals")
		}
		
		Label {
			text: ""
		}
		
		CheckBox {
			id: showBackground
			text: i18n("Show background")
		}
		
		Label {
			text: i18n("On click:")
		}
		
		ExclusiveGroup { id: clickGroup }
		
		RadioButton {
			Layout.row: 7
			Layout.column: 1
			exclusiveGroup: clickGroup
			checked: cfg_onClickAction == 'refresh'
			text: i18n("Refresh")
			onClicked: {
				cfg_onClickAction = 'refresh'
			}
		}

		RadioButton {
			Layout.row: 8
			Layout.column: 1
			exclusiveGroup: clickGroup
			checked: cfg_onClickAction == 'website'
			text: i18n("Open market's website")
			onClicked: {
				cfg_onClickAction = 'website'
			}
		}
	}
}
