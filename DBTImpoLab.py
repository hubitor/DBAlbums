#!/usr/bin/env python
# -*- coding: utf-8 -*-


from sys import argv
from os import path
from PyQt5.QtWidgets import QApplication
from PyQt5.QtCore import QSettings
#from DBDatabase import connectDatabase
from DBFunction import buildlistcategory
#from DBTImpoTAG import DBMediasTags
from json import load
from PyQt5.QtCore import QObject

# ########################################################
def testini(envt):
	"""Connect base MySQL/Sqlite."""
	FILE__INI = 'DBAlbums.ini'
	configini = QSettings(FILE__INI, QSettings.IniFormat)
	configini.beginGroup(envt)
	#MODE_SQLI = configini.value('typb')
	BASE_RAC = r'' + configini.value('raci')
	RACI_DOU = configini.value('cate')
	RACI_SIM = configini.value('cats')
	configini.endGroup()
	if RACI_DOU is not None:
		list_category = buildlistcategory(configini, RACI_DOU, BASE_RAC, 'D')
	if RACI_SIM is not None:
		list_category += buildlistcategory(configini, RACI_SIM, BASE_RAC, 'S')
	for row in list_category:
		print(row)


class JsonParams(QObject):
	def __init__(self, file_json='DBAlbums.json'):
		"""Init invent, build list albums exists in database."""
		super(JsonParams, self).__init__()
		with open(file_json) as data_file:    
			self.data = load(data_file)

	def getMember(self, member):
		"""Return array infos member of json."""
		return(self.data[member])

	def buildListEnvt(self, curenvt):
		"""Build list environments."""
		list_envt = []
		listenvt = self.data["environments"]
		for envt in listenvt:
			if listenvt[envt]==curenvt:
				Curt_Evt = len(list_envt)
			list_envt.append(listenvt[envt])
		return list_envt, Curt_Evt

	def buildDictScore(self):
		"""Build list scoring."""
		dict_score = {}
		listescore = self.data["score"]
		for envt in listescore:
			dict_score.update({int(envt): listescore[envt]})
		return dict_score

	def buildCategories(self,  envt):
		"""Build list category simple and double from json file."""
		racine =  self.data[envt]["raci"]
		category = self.data[envt]["cate"]
		list_pathcollection = []
		list_pathcollection = self.buildCategory(racine, category)
		return list_pathcollection

	def buildCategory(self,  racine, category):
		"""Build list for one category."""
		list_pathcollection = []
		listcate = self.data[category]
		for cate in listcate:
			if isinstance( listcate[cate], list):
				# array elements
				for souslistcate in listcate[cate]:
					family = souslistcate["family"]
					racate = souslistcate["name"]
					mode = souslistcate["mode"]
					racate = path.join(racine, racate)
					list_pathcollection.append([cate, mode, racate, family])
			else:
				# one element
				family = listcate[cate]["family"]
				racate = listcate[cate]["name"]
				mode = listcate[cate]["mode"]
				racate = path.join(racine, racate)
				list_pathcollection.append([cate, mode, racate, family])
		return list_pathcollection


if __name__ == '__main__':
	app = QApplication(argv)
	# debug
	#envt = 'LOSSLESS_TEST'
	#boolconnect, dbbase, modsql, rootDk, listcategory = connectDatabase(envt)
	testini('LOSSLESS')
	print("---")
	
	params = JsonParams()
	mylist,  curevt = params.buildListEnvt('MP3')
	print(curevt)
	for row in mylist:
		print(row)
	#print(mylist)
	#for key in mylist:
	#	print(key + " = " + str(mylist[key]))
	
	#list_infostrack = DBMediasTags().getTagMediaAPE('E:\\Work\\ZTest\\Hexstatic.ape')
	#coveral = DBMediasTags().getImageFromTagAPE('E:\\Work\\ZTest\\01 - Orb - Valley.ape', 'E:\\Work\\ZTest\\', 'APEkkxxyy')
	#print(list_infostrack)
	#cb = QApplication.clipboard()
	#cb.clear(mode=cb.Clipboard )
	#cb.setText("Clipboard Text", mode=cb.Clipboard)
	
	
	#E:\Work\ZTest\TAG_bluid\TECHNO\Download\Caia - The Magic Dragon (2003)\01-caia--the_magic_dragon-csa.ape
	#timeduration = DBMediasTime('E:\\Work\\ZTest\\Hexstatic.ape').totalduration
	#timeduration = processfindduration.getLengthMedia()
	#print('koala', timeduration)

	rc = app.exec_()
	exit(rc)

