#!/usr/bin/env python
# -*- coding: utf-8 -*-

# ############################################################################
# # Audio pyQT5 Player by SFI
# ############################################################################
from sys import argv
from os import path
from PyQt5.QtCore import Qt, QUrl, pyqtSignal
from PyQt5.QtMultimedia import QMediaContent, QMediaPlayer, QMediaPlaylist#, QMediaMetaData
from PyQt5.QtWidgets import (QApplication, QHBoxLayout, QPushButton, QSlider,
							QLabel, QMainWindow, QStyle, QWidget, QMessageBox)

VERS_PROG = '1.00'
TITL_PROG = "Player v{v} : ".format(v=VERS_PROG)
WINS_ICO = "DBAlbums-icone.ico"


# ##################################################################
# PLAYER PQT5 V2
class DBPlayer(QWidget):
	# signal
	signaltxt = pyqtSignal(str)
	signalnum = pyqtSignal(int)

	def __init__(self):
		super(DBPlayer, self).__init__()
		self.setMaximumSize(16777215, 35)
		# Init Player
		self.messtitle = TITL_PROG
		self.namemedia = ''
		self.albumname = ''
		self.currentPlaylist = QMediaPlaylist()
		self.player = QMediaPlayer()
		self.player.stateChanged.connect(self.qmp_stateChanged)
		self.player.positionChanged.connect(self.qmp_positionChanged)
		self.player.volumeChanged.connect(self.qmp_volumeChanged)
		self.player.durationChanged.connect(self.qmp_durationChanged)
		self.player.setVolume(60)
		# Init GUI
		self.setLayout(self.addControls())
		self.infoBox = None

	def addControls(self):
		# buttons
		self.playBtn = QPushButton()
		self.playBtn.setIcon(self.style().standardIcon(QStyle.SP_MediaPlay))
		self.playBtn.setStyleSheet('border: 0px;')
		stopBtn = QPushButton()
		stopBtn.setIcon(self.style().standardIcon(QStyle.SP_MediaStop))
		stopBtn.setStyleSheet('border: 0px;')
		prevBtn = QPushButton()
		prevBtn.setIcon(self.style().standardIcon(QStyle.SP_MediaSkipBackward))
		prevBtn.setStyleSheet('border: 0px;')
		nextBtn = QPushButton()
		nextBtn.setIcon(self.style().standardIcon(QStyle.SP_MediaSkipForward))
		nextBtn.setStyleSheet('border: 0px;')
		volumeDescBtn = QPushButton('▼')
		volumeDescBtn.setIcon(self.style().standardIcon(QStyle.SP_MediaVolume))
		volumeDescBtn.setMaximumWidth(30)
		volumeDescBtn.setStyleSheet('border: 0px;')
		volumeIncBtn = QPushButton('▲')
		volumeIncBtn.setIcon(self.style().standardIcon(QStyle.SP_MediaVolume))
		volumeIncBtn.setMaximumWidth(40)
		volumeIncBtn.setStyleSheet('border: 0px;')
		infoBtn = QPushButton()
		infoBtn.setIcon(self.style().standardIcon(QStyle.SP_FileDialogContentsView))
		infoBtn.setStyleSheet('border: 0px;')

		# seek slider
		self.seekSlider = QSlider(Qt.Horizontal, self)
		self.seekSlider.setMinimum(0)
		self.seekSlider.setMaximum(100)
		self.seekSlider.setTracking(False)

		# labels position start/end
		self.seekSliderLabel1 = QLabel('0:00')
		self.seekSliderLabel2 = QLabel('0:00')

		# layout
		controlArea = QHBoxLayout()
		controlArea.addWidget(prevBtn)
		controlArea.addWidget(self.playBtn)
		controlArea.addWidget(stopBtn)
		controlArea.addWidget(nextBtn)
		controlArea.addWidget(self.seekSliderLabel1)
		controlArea.addWidget(self.seekSlider)
		controlArea.addWidget(self.seekSliderLabel2)
		controlArea.addWidget(infoBtn)
		controlArea.addWidget(volumeDescBtn)
		controlArea.addWidget(volumeIncBtn)

		# link buttons to media
		self.seekSlider.sliderMoved.connect(self.seekPosition)
		self.playBtn.clicked.connect(self.playHandler)
		stopBtn.clicked.connect(self.stopHandler)
		volumeDescBtn.clicked.connect(self.decreaseVolume)
		volumeIncBtn.clicked.connect(self.increaseVolume)
		prevBtn.clicked.connect(self.prevItemPlaylist)
		nextBtn.clicked.connect(self.nextItemPlaylist)
		infoBtn.clicked.connect(self.displaySongInfo)

		return controlArea

	def playHandler(self):
		if self.player.state() == QMediaPlayer.PlayingState:
			self.player.pause()
			message = (' [Paused at position %s]' % self.seekSliderLabel1.text())
			self.messtitle = self.namemedia+message
			self.signaltxt.emit(self.messtitle)
		else:
			if self.player.state() == QMediaPlayer.StoppedState:
				if self.player.mediaStatus() == QMediaPlayer.NoMedia:
					if self.currentPlaylist.mediaCount() != 0:
						self.player.setPlaylist(self.currentPlaylist)
				elif self.player.mediaStatus() == QMediaPlayer.LoadedMedia:
					self.player.play()
				elif self.player.mediaStatus() == QMediaPlayer.BufferedMedia:
					self.player.play()
			elif self.player.state() == QMediaPlayer.PlayingState:
				pass
			elif self.player.state() == QMediaPlayer.PausedState:
				self.player.play()
			if self.player.volume() is not None and self.player.state() == QMediaPlayer.PlayingState:
				message = ' [Volume %d]' % self.player.volume()
				self.messtitle = self.namemedia+message
				self.signaltxt.emit(self.messtitle)

	def stopHandler(self):
		if self.player.state() == QMediaPlayer.PlayingState:
			self.stopState = True
			self.player.stop()
		elif self.player.state() == QMediaPlayer.PausedState:
			self.player.stop()
		elif self.player.state() == QMediaPlayer.StoppedState:
			pass
		if self.player.volume()is not None and self.player.state() == QMediaPlayer.PlayingState:
			self.messtitle = self.namemedia+(' [Stopped]')
			self.signaltxt.emit(self.messtitle)

	def qmp_stateChanged(self):
		if self.player.state() == QMediaPlayer.StoppedState:
			self.player.stop()
		# buttons icon play/pause change
		if self.player.state() == QMediaPlayer.PlayingState:
			self.playBtn.setIcon(self.style().standardIcon(QStyle.SP_MediaPause))
		else:
			self.playBtn.setIcon(self.style().standardIcon(QStyle.SP_MediaPlay))

	def qmp_positionChanged(self, position):
		# update position slider
		self.seekSlider.setValue(position)
		# update the text label
		self.seekSliderLabel1.setText('%d:%02d' % (int(position/60000), int((position/1000) % 60)))

	def seekPosition(self, position):
		sender = self.sender()
		if isinstance(sender, QSlider):
			if self.player.isSeekable():
				self.player.setPosition(position)

	def qmp_volumeChanged(self):
		if self.player.volume()is not None:
			message = (' [Playing at Volume %d]' % (self.player.volume()))
			if self.namemedia != '':
				self.messtitle = self.namemedia+message
			else:
				self.messtitle = "Initialisation player "+message
			self.signaltxt.emit(self.messtitle)

	def qmp_durationChanged(self, duration):
		self.seekSlider.setRange(0, duration)
		self.seekSliderLabel2.setText('%d:%02d' % (int(duration/60000), int((duration/1000) % 60)))
		nummedia = self.currentPlaylist.mediaCount()
		curmedia = self.currentPlaylist.currentIndex()
		#artist = self.player.metaData(QMediaMetaData.Author)
		#tittle = self.player.metaData(QMediaMetaData.Title)
		self.namemedia = path.basename(self.homMed[curmedia])
		self.namemedia = '[%02d/%02d' % (curmedia+1, nummedia) + '] "' + self.namemedia + '"'
		self.buildPlaylist()
		message = (' [Playing at Volume %d]' % (self.player.volume()))
		if self.player.volume() is not None and self.player.state() == QMediaPlayer.PlayingState:
			self.messtitle = self.namemedia+message
			self.signaltxt.emit(self.messtitle)
	
	def buildPlaylist(self):
		"""Build play list."""
		nummedia = self.currentPlaylist.mediaCount()
		curmedia = self.currentPlaylist.currentIndex() + 1
		compteur = 1
		self.textplaylist = '<b>' + self.albumname + '</b>'
		self.textplaylist += '<table class="tftable" border="0">'
		for namemedia in self.homMed:
			media = path.basename(namemedia)
			media = '[%02d/%02d' % (compteur, nummedia) + '] "' + media + '"'
			if curmedia == compteur:
				self.textplaylist += '<tr><td><b>' + media + '</b></td></tr>'
			else:	
				self.textplaylist += '<tr><td>' + media + '</td></tr>'
			compteur += 1
		self.textplaylist = self.textplaylist + '</table>'
		self.playBtn.setToolTip(self.textplaylist)
		self.signalnum.emit(curmedia-1)
		
	def increaseVolume(self):
		"""Volume +."""
		vol = self.player.volume()
		vol = min(vol+5, 100)
		self.player.setVolume(vol)

	def decreaseVolume(self):
		"""Volume -."""
		vol = self.player.volume()
		vol = max(vol-5, 0)
		self.player.setVolume(vol)

	def prevItemPlaylist(self):
		self.player.playlist().previous()
		if self.currentPlaylist.currentIndex() == -1:
			self.player.playlist().previous()

	def nextItemPlaylist(self):
		self.player.playlist().next()
		if self.currentPlaylist.currentIndex() == -1:
			self.player.playlist().next()

	def addMediaslist(self, listmedias, position, albumname):
		if self.currentPlaylist.mediaCount() > 0:
			self.currentPlaylist.removeMedia(0, self.currentPlaylist.mediaCount())
			self.player.stop()
			self.stopHandler()
		self.currentPlaylist.removeMedia(0, self.currentPlaylist.mediaCount())
		self.albumname = albumname
		if listmedias:
			self.homMed = listmedias
			for media in self.homMed:
				self.currentPlaylist.addMedia(QMediaContent(QUrl.fromLocalFile(media)))
			self.currentPlaylist.setCurrentIndex(position)
			self.playHandler()

	def displaySongInfo(self):
		# extract datas
		metaDataKeyList = self.player.availableMetaData()
		fullText = '<table class="tftable" border="0">'
		for key in metaDataKeyList:
			value = str(self.player.metaData(key)).replace("'", "").replace("[", "").replace("]", "")
			if key == 'Duration':
				value = '%d:%02d' % (int(int(value)/60000), int((int(value)/1000) % 60))
			fullText = fullText + '<tr><td>' + key + '</td><td>' + value + '</td></tr>'
		fullText = fullText + '</table>'
		# re-init
		if self.infoBox is not None:
			self.infoBox.destroy()
		# infos box
		self.infoBox = QMessageBox(self)
		self.infoBox.setWindowTitle('Detailed Song Information')
		self.infoBox.setTextFormat(Qt.RichText)
		self.infoBox.addButton('OK', QMessageBox.AcceptRole)
		self.infoBox.setText(fullText)
		self.infoBox.show()


class MainExemple(QMainWindow):
	def __init__(self, parent=None):
		super(MainExemple, self).__init__(parent)
		# Init GUI
		PlayerAudio = DBPlayer()
		self.setCentralWidget(PlayerAudio)
		self.show()

		PlayerAudio.signaltxt.connect(self.txtplayeraudio)

		PlayerAudio.addMediaslist(("E:\WORK\ZTest\Morten Granau.flac",), 0)
		PlayerAudio.player.play()

	def txtplayeraudio(self, message):
		print(message)


if __name__ == '__main__':
	app = QApplication(argv)
	player = MainExemple()
	rc = app.exec_()
	exit(rc)
