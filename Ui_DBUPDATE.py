# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'R:\Projets\DBALBUMSQT5\DBUPDATE.ui'
#
# Created by: PyQt5 UI code generator 5.9
#
# WARNING! All changes made in this file will be lost!

from PyQt5 import QtCore, QtGui, QtWidgets

class Ui_UpdateWindows(object):
    def setupUi(self, UpdateWindows):
        UpdateWindows.setObjectName("UpdateWindows")
        UpdateWindows.resize(750, 562)
        self.gridLayout = QtWidgets.QGridLayout(UpdateWindows)
        self.gridLayout.setObjectName("gridLayout")
        self.verticalLayout = QtWidgets.QVBoxLayout()
        self.verticalLayout.setObjectName("verticalLayout")
        self.horizontalLayout = QtWidgets.QHBoxLayout()
        self.horizontalLayout.setObjectName("horizontalLayout")
        self.lab_result = QtWidgets.QLabel(UpdateWindows)
        self.lab_result.setObjectName("lab_result")
        self.horizontalLayout.addWidget(self.lab_result)
        self.progressBar = QtWidgets.QProgressBar(UpdateWindows)
        sizePolicy = QtWidgets.QSizePolicy(QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Fixed)
        sizePolicy.setHorizontalStretch(0)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(self.progressBar.sizePolicy().hasHeightForWidth())
        self.progressBar.setSizePolicy(sizePolicy)
        self.progressBar.setProperty("value", 0)
        self.progressBar.setObjectName("progressBar")
        self.horizontalLayout.addWidget(self.progressBar)
        self.lab_advance = QtWidgets.QLabel(UpdateWindows)
        self.lab_advance.setEnabled(True)
        sizePolicy = QtWidgets.QSizePolicy(QtWidgets.QSizePolicy.Minimum, QtWidgets.QSizePolicy.Fixed)
        sizePolicy.setHorizontalStretch(0)
        sizePolicy.setVerticalStretch(0)
        sizePolicy.setHeightForWidth(self.lab_advance.sizePolicy().hasHeightForWidth())
        self.lab_advance.setSizePolicy(sizePolicy)
        self.lab_advance.setMinimumSize(QtCore.QSize(0, 70))
        self.lab_advance.setObjectName("lab_advance")
        self.horizontalLayout.addWidget(self.lab_advance)
        self.verticalLayout.addLayout(self.horizontalLayout)
        self.tbl_update = QtWidgets.QTableView(UpdateWindows)
        self.tbl_update.setAlternatingRowColors(True)
        self.tbl_update.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.tbl_update.setObjectName("tbl_update")
        self.verticalLayout.addWidget(self.tbl_update)
        self.horizontalLayout_2 = QtWidgets.QHBoxLayout()
        self.horizontalLayout_2.setObjectName("horizontalLayout_2")
        self.lcdTime = QtWidgets.QLCDNumber(UpdateWindows)
        self.lcdTime.setObjectName("lcdTime")
        self.horizontalLayout_2.addWidget(self.lcdTime)
        spacerItem = QtWidgets.QSpacerItem(40, 20, QtWidgets.QSizePolicy.Expanding, QtWidgets.QSizePolicy.Minimum)
        self.horizontalLayout_2.addItem(spacerItem)
        self.checkBoxStart = QtWidgets.QCheckBox(UpdateWindows)
        self.checkBoxStart.setChecked(True)
        self.checkBoxStart.setObjectName("checkBoxStart")
        self.horizontalLayout_2.addWidget(self.checkBoxStart)
        self.btn_action = QtWidgets.QPushButton(UpdateWindows)
        self.btn_action.setObjectName("btn_action")
        self.horizontalLayout_2.addWidget(self.btn_action)
        self.btn_quit = QtWidgets.QPushButton(UpdateWindows)
        self.btn_quit.setObjectName("btn_quit")
        self.horizontalLayout_2.addWidget(self.btn_quit)
        self.verticalLayout.addLayout(self.horizontalLayout_2)
        self.gridLayout.addLayout(self.verticalLayout, 0, 0, 1, 1)

        self.retranslateUi(UpdateWindows)
        QtCore.QMetaObject.connectSlotsByName(UpdateWindows)

    def retranslateUi(self, UpdateWindows):
        _translate = QtCore.QCoreApplication.translate
        UpdateWindows.setWindowTitle(_translate("UpdateWindows", "Form"))
        self.lab_result.setText(_translate("UpdateWindows", "TextLabel"))
        self.lab_advance.setText(_translate("UpdateWindows", "TextLabel"))
        self.checkBoxStart.setText(_translate("UpdateWindows", "Start Update directly"))
        self.btn_action.setText(_translate("UpdateWindows", "Update"))
        self.btn_quit.setText(_translate("UpdateWindows", "Abort"))


if __name__ == "__main__":
    import sys
    app = QtWidgets.QApplication(sys.argv)
    UpdateWindows = QtWidgets.QWidget()
    ui = Ui_UpdateWindows()
    ui.setupUi(UpdateWindows)
    UpdateWindows.show()
    sys.exit(app.exec_())

