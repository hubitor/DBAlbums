############################################################################################
# Construction INVENT
$Process = "BUILD_INVENT_FUNCTIONS";
# Init Variables 
$version = '1.09';

# Write-Host Waiting
Function Super-Title{
	param ([parameter(Mandatory = $True)][Datetime] $Start,
		   [parameter(Mandatory = $False)][String] $Label='',
		   [parameter(Mandatory = $False)][Int32]  $Width=154,
		   [parameter(Mandatory = $False)][String] $Deco='*')

	#$Colors = @("DarkBlue","DarkGreen","DarkCyan","DarkRed","DarkMagenta","DarkYellow","Gray","Blue","Green","Cyan","Magenta","Yellow","White");
	#$foregroundcolor = Get-Random -Input $Colors;
	$Minute = [math]::Round(((Get-Date) - $Start).TotalMinutes,0);
	If ($Minute -eq 0){
		$Second = [math]::Round(((Get-Date) - $Start).TotalSeconds,0);
		$Length = [string]$Second + ' sec';
	} Else {
		$Length = [string]$Minute + ' min(s)';
	}
	$Tittle = $Deco*10 + ' ' + (Get-Date).tostring('HH:mm:ss') + " -- Dur�e: $Length -- $Label " + $Deco*($Width-33-$Label.Length-$Length.Length) + "`n`r";
	Write-Host -foregroundcolor 'Green' $Tittle;
}

Function Run-UpdateAlbum{
	param ([parameter(Mandatory = $true)][string] $Album_IDCD)
	
	$Album_Exist = Get-AlbumMysql -Album_IDCD $Album_IDCD;
	If ($Album_Exist){
		$Album_Path = Test-Path -LiteralPath $Album_Exist.path
		if ($Album_Path){
			$Album_Rep = Get-Item -LiteralPath $Album_Exist.path | Where-Object { $_.PSIsContainer } | Select-Object Name,Fullname,LastWriteTime;
		} Else {
			#path modified
			write-host -foregroundcolor "Magenta" ('...path modified '+$Album_Exist.path)
			$Album_Rep = Get-childItem -Path ($Album_Exist.path+'*') | Where-Object { $_.PSIsContainer } | Select-Object Name,Fullname,LastWriteTime;
			If ((Get-Item -LiteralPath $Album_Exist.path).length -eq 0){
				write-host -foregroundcolor "Magenta" ('...path not find')
				Break
			} ELse {
				write-host -foregroundcolor "Magenta" ('...path ok...... '+$Album_Rep.Fullname)
			}
		}
		$Family = $Album_Exist.Family
		$Category = $Album_Exist.Category
		# ALBUMS TRANSFERT ID + NAME + DATE 
		$Album_Result = Get-AnalyseAlb -Album $Album_Rep -Family $Family -Category $Category;
		$Album_Result.ID_CD = $Album_Exist.ID_CD;
		$Album_Result.Name = $Album_Exist.Name;
		$Album_Result.Date_Insert = ($Album_Exist.Date_Insert).ToString("yyyy-MM-dd HH:mm:ss");
		# DELETE ALBUMS
		$reqStr = "DELETE FROM $Tbl_Tracks WHERE ``ID_CD``="+$Album_Result.ID_CD;
		$rows = Execute-MySQLNonQuery -MySqlCon $MySqlCon -requete $reqStr
		$reqStr = "DELETE FROM $Tbl_Covers WHERE ``MD5``='"+$Album_Result.MD5+"'";
		$rows = Execute-MySQLNonQuery -MySqlCon $MySqlCon -requete $reqStr
		$reqStr = "DELETE FROM $Tbl_Albums WHERE ``ID_CD``="+$Album_Result.ID_CD;
		$rows = Execute-MySQLNonQuery -MySqlCon $MySqlCon -requete $reqStr
		# INSERT COVER
		Covers-ToMySQL -MySqlCon $MySqlCon -PathCover $Album_Result.cover -MD5 $Album_Result.MD5;
		# INSERT TRACKS
		Switch ($Album_Result.Typ_Tag){
			'TAG' {
				$TAGS_Result = (Get-ListeTag -AlbumTAG $Album_Result);
			}
			'CUE' {
				$TAGS_Result = (Get-ListeCue -AlbumCUE $Album_Result);
			}
		}
		If ($TAGS_Result){
			$TAGS_Result | ForEach-Object { $_.Statut='PRESENT' }
			# MAJ ALBUM INFOS
			$Album_Result.Qty_Tracks = ($TAGS_Result | Measure-Object).count;
			$Duration = 0;
			$TAGS_Result | Group-Object ID_CD | %{$Duration += ($_.Group | Measure-Object TAG_Duration -Sum).Sum};
			$ts = New-TimeSpan -Seconds $Duration;
			$Album_Result.Duration = $Duration;
			$Album_Result.Length = ('{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds);
			$TAGS_Result |  %{$maxCd = ($_ | Measure-Object TAG_Disc -Maximum).Maximum};
			If (($Album_Result.Qty_CD -ne $maxCd) -and ($maxCd -ne 0)){
				Write-Host -foregroundcolor "yellow" (' '*10+" | "+'probleme Qty_CD virtuelcd:'+$maxCd+'|'+'repcd:'+$Album_Result.Qty_CD)
				if ($Album_Result.Name -match ([string]$maxCd+"CD")){
					Write-Host -foregroundcolor "magenta" (' '*10+" | "+'correction Qty_CD = virtuelcd:'+$maxCd+' | '+'old:'+$Album_Result.Qty_CD)
					$Album_Result.Qty_CD = $maxCd
				}
			}
			# ENR Liste TRACKS mysql
			ArrayToMySQL -MySqlCon $MySqlCon -TabPower $TAGS_Result -TblMysql $Tbl_Tracks;
		} Else {
			Write-Host -foregroundcolor "yellow" -NoNewLine '#UpdateAlbum';
			Anno-toMySQL -MySqlCon $MySqlCon -ID_CD $Album_Result.ID_CD -Path $Album_Result.Path -Mess 'Error No Track List';
		}
		# UPDATE ALBUMS
		$Album_Result.Statut = 'PRESENT';
		ArrayToMySQL -MySqlCon $MySqlCon -TabPower $Album_Result -TblMysql $Tbl_Albums;
		
		Write-host ($Album_Result | Select-Object ID_CD, Name, Path, Qty_CD, Qty_Audio, Length | Format-Table | Out-String)
		Write-host ($TAGS_Result | Select-Object ODR_Track, FIL_Track, TAG_Artists, TAG_Album, TAG_Genres, TAG_Length  | Format-Table | Out-String)
	}
}


# liste les albums d'un r�pertoire
Function Get-ListeAlb{
	param ([parameter(Mandatory = $true)][string] $pathAlbumsList,
		   [parameter(Mandatory = $true)][string] $Family,
		   [parameter(Mandatory = $false)][string] $Category="")

	$AlbumsList = $TracksList = @();
	$Albums_liste = (Get-ChildItem -LiteralPath $pathAlbumsList | Where-Object { $_.PSIsContainer } | Sort-Object Name | Select-Object Name,Fullname,LastWriteTime);
	ForEach ($Album_Rep in $Albums_liste){
		$Album_Result = $TAGS_Result = @();
		$global:Compteur++;
		# no audio = next album
		$Audi_Count = (Get-ChildItem -LiteralPath $Album_Rep.Fullname -file -recurse | Where-Object { $global:MaskMusic -contains $_.Extension }).count;
		if ($Audi_Count -eq 0){
			Write-Host -foregroundcolor "yellow" ("`r"+' '*6+"{5,-7} | {0:00000} | ({1}) | {2:00000} | ({3}) | {4,-111}" -f $global:Compteur, 'X', 0 ,'XXX', ('NO AUDIO :'+$Album_Rep.Name).PadRight(111,' '), "XxXxXxX");
			Continue
		}
		# STATUT
		$Album_Exist = (Get-AlbumExist -Album $Album_Rep); 
		If ($Album_Exist){
			# on prend la date la plus r�cente des �l�ments de l'album
			$Recent_Date = ((Get-ChildItem -LiteralPath $Album_Rep.FullName | Select LastWriteTime).LastWriteTime | measure-object	-maximum).maximum
			If (($global:INVENTMODE -eq 'UPDATE') -and (($Recent_Date -gt $Album_Exist.Date_Modifs) -or ((Get-Date $Album_Rep.LastWriteTime) -gt (Get-Date ($Album_Exist.Date_Modifs))))){
				# UPDATE
				$Album_Result = Get-AnalyseAlb -Album $Album_Rep -Family $Family -Category $Category;
				$global:cptIDCD++;
				$Album_Result.ID_CD = $Album_Exist.ID_CD;
				$Album_Result.Date_Insert = ($Album_Exist.Date_Insert).ToString("yyyy-MM-dd HH:mm:ss");
				$Album_Result.Statut = 'UPDATE';
			} Else {
				# PRESENT NO UPDATE
				$Album_Result = $Album_Exist;
			}
		} Else {
			# NEW
			$Album_Result = Get-AnalyseAlb -Album $Album_Rep -Family $Family -Category $Category;
			$global:cptIDCD++;
			$Album_Result.ID_CD = $global:cptIDCD;
			$Album_Result.Statut = 'NEW';
		}
		#Write-Host -NoNewLine ("`r"+' '*6+"{5,-7} | {0:0000} | ({1}) | {2:0000} | ({3}) | {4,-111}" -f $global:Compteur, $Album_Result.Statut[0], [int32]$Album_Result.ID_CD,	$Album_Result.Typ_Tag, ($Album_Rep.Name).PadRight(111,' '), $Album_Result.Category);
		Write-Host ("`r"+' '*6+"{5,-7} | {0:00000} | ({1}) | {2:00000} | ({3}) | {4,-111}" -f $global:Compteur, $Album_Result.Statut[0], [int32]$Album_Result.ID_CD,	$Album_Result.Typ_Tag, ($Album_Rep.Name).PadRight(111,' '), $Album_Result.Category);
		#Write-Host (' '*6+"{5,-7} | {0:0000} | ({1}) | {2:0000} | ({3}) | {4,-111}" -f $global:Compteur, $Album_Result.Statut[0], [int32]$Album_Result.ID_CD,  $Album_Result.Typ_Tag, ($Album_Rep.Name).PadRight(111,' '), $Album_Result.Category);
		
		# TRACKS
		Switch ($Album_Result.Statut){
			# MAJ TAG
			{@("UPDATE") -contains $_ } {
				$reqStr	 = "DELETE TRK FROM $Tbl_Tracks TRK WHERE ``ID_CD``="+$Album_Result.ID_CD;
				$rows = Execute-MySQLNonQuery -MySqlCon $MySqlCon -requete $reqStr
			}
			{@("NEW", "UPDATE") -contains $_ } {
				Switch ($Album_Result.Typ_Tag){
					'TAG' {
						$TAGS_Result = (Get-ListeTag -AlbumTAG $Album_Result);
					}
					'CUE' {
						$TAGS_Result = (Get-ListeCue -AlbumCUE $Album_Result);
					}
				}
				If ($TAGS_Result){
					# MAJ ALBUM
					$Album_Result.Qty_Tracks = ($TAGS_Result | Measure-Object).count;
					$Duration = 0;
					$TAGS_Result | Group-Object ID_CD | %{$Duration += ($_.Group | Measure-Object TAG_Duration -Sum).Sum};
					$ts = New-TimeSpan -Seconds $Duration;
					$Album_Result.Duration = $Duration;
					$Album_Result.Length = ('{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds);
					$TAGS_Result |  %{$maxCd = ($_ | Measure-Object TAG_Disc -Maximum).Maximum};
					if (($Album_Result.Qty_CD -ne $maxCd) -and ($maxCd -ne 0)){
						Write-Host -foregroundcolor "yellow" (' '*10+" | "+'probleme Qty_CD virtuelcd:'+$maxCd+'|'+'repcd:'+$Album_Result.Qty_CD)
						if ($Album_Result.Name -match ([string]$maxCd+"CD")){
							Write-Host -foregroundcolor "magenta" (' '*10+" | "+'correction Qty_CD = virtuelcd:'+$maxCd+' | '+'old:'+$Album_Result.Qty_CD)
							$Album_Result.Qty_CD = $maxCd
						}
					}
					# on cumul pour le csv
					$TracksList += $TAGS_Result;
					# ENR Liste TRACKS mysql
					$StatutBackup = ''+($TAGS_Result[0].Statut)
					$TAGS_Result | ForEach-Object { $_.Statut='PRESENT' }
					ArrayToMySQL -MySqlCon $MySqlCon -TabPower $TAGS_Result -TblMysql $Tbl_Tracks;
					$TAGS_Result | ForEach-Object { $_.Statut=$StatutBackup }
				} Else {
					Write-Host -foregroundcolor "yellow" -NoNewLine '#pb tag track';
					Anno-toMySQL -MySqlCon $MySqlCon -ID_CD $Album_Result.ID_CD -Path $Album_Result.Path -Mess 'Error No Track List';
				}
			}
		}
		
		# ALBUMS
		$AlbumsList += $Album_Result;
		# CLEAN NAME
		If (!($Category -eq "")){
			# MP3
			$albclean = Get-CleanAlbumName -Album $Album_Result.Name
			#Write-Host -foregroundcolor "DarkRed" (' '*8+"| MP3> "+($albclean)+" <> "+ ($Album_Result.Name))
			$Album_Result.Name = $albclean
		} else {
			# test name
			If (!((Get-CleanAlbumName -Album $Album_Rep.Name) -eq $Album_Rep.Name)){
				$albclean = Get-CleanAlbumName -Album $Album_Rep.Name
				#Write-Host -foregroundcolor "DarkRed" (' '*8+"| LOSSLESS TEST> "+($albclean)+" <> "+ ($Album_Rep.Name))###################
			}
		}
		# YEAR via media
		If ($Album_Result.Year -eq "????"){
			$Album_Result.Year = $TAGS_Result[0].TAG_Year
		}
		# ENR Ligne ALBUM mysql
		Switch ($Album_Result.Statut){
			{@("UPDATE") -contains $_ } {
				$reqStr	 = "DELETE ALB FROM $Tbl_Albums ALB WHERE ``ID_CD``="+$Album_Result.ID_CD;
				$rows = Execute-MySQLNonQuery -MySqlCon $MySqlCon -requete $reqStr
				$reqStr	 = "DELETE COV FROM $Tbl_Covers COV WHERE ``MD5``='"+$Album_Result.MD5+"'";
				$rows = Execute-MySQLNonQuery -MySqlCon $MySqlCon -requete $reqStr
			}
			{@("NEW", "UPDATE") -contains $_ } {
				$StatutBackup = $Album_Result.Statut
				$Album_Result.Statut ="PRESENT"
				ArrayToMySQL -MySqlCon $MySqlCon -TabPower $Album_Result -TblMysql $Tbl_Albums;
				$Album_Result.Statut = $StatutBackup
				# COVER
				Covers-ToMySQL -MySqlCon $MySqlCon -PathCover $Album_Result.cover -MD5 $Album_Result.MD5;
			}
		}
	}
	Return (@()+$AlbumsList),(@()+$TracksList);
}


# Analyse un Album via son r�pertoire
Function Get-AnalyseAlb{
	param ([parameter(Mandatory = $true)][PSObject] $Album,
		   [parameter(Mandatory = $true)][string] $Family,
		   [parameter(Mandatory = $false)][string] $Category="")
	
	[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null;
	
	try{
		##################### CORRECTIONS
		# on retire les caract�res parasites
		$Reps_Album = (Get-ChildItem -LiteralPath $Album.FullName | Where-Object { $_.PSIsContainer } | Sort-Object Name | Select-Object Name,Fullname);
		ForEach ($Rep_Album in $Reps_Album){
				# liste code ASCII ($clphys.name).ToCharArray() | %{"$_ $([int][char]$_)"}
				#? caractere parasite 8206 8211
				$Parasite = ((($Rep_Album.name).ToCharArray() | Where-Object {([int][char]$_ -eq 8206) -or([int][char]$_ -eq 8211)}) | Measure-Object).count;
				If ($Parasite -gt 0) {
					# on renomme
					Write-Host -foregroundcolor "Magenta" ("`r`n"+' '*10+"| Correction Problem ASCII"+$Album.Name+'['+$Rep_Album.Name+']');
					$NewName = ([string](($Rep_Album.Name).ToCharArray() | % { if (([int][char]$_ -ne 8206) -and ([int][char]$_ -ne 8211)){$_}})).replace('	 ',' - ');
					Rename-Item	 -LiteralPath $Rep_Album.FullName -newname $NewName;
				}
		}
		# si pas de fichier cover alors on l'extrait d'un tag si possible
		$List_Cover = (Get-ChildItem -LiteralPath $Album.FullName -file -recurse | Where-Object { $global:CoverAlbum -contains $_.name })
		if (!($List_Cover)){
			# on regardextrait depuis le tag
			if ($nbaudioRac -eq 0){
				# double album ou plus
				ForEach ($rep in $repMusic){
					Get-CoverFromTag -Coverpath $rep.name
				}
			} Else {
				# simple album
				Get-CoverFromTag -Coverpath $album.Fullname
			}
		}
		# Correction REM DATE ajout + test des fichiers .cue 
		$CueR_Count = (Album-TestCues -AlbCue $Album);
		
		##################### INVENTAIRE	
		# on compte le nombre de fichier audio dans la racine
		$AudR_Count = (Get-ChildItem -LiteralPath $Album.Fullname -file | Where-Object { $global:MaskMusic -contains $_.Extension }).count;
		# on compte le nombre de fichiers audio total
		$Audi_Count = (Get-ChildItem -LiteralPath $Album.Fullname -file -recurse | Where-Object { $global:MaskMusic -contains $_.Extension }).count;
		# on compte le nombre de sous-r�pertoires audio
		$Reps_Album = Get-ChildItem -LiteralPath $Album.Fullname -file -recurse | Where-Object { $global:MaskMusic -contains $_.Extension } | group-object -property directoryname | Select-Object Name;
		$RepA_Count = $Reps_Album.Name.count
		# on compte le nombre de sous-r�pertoires images
		$RepC_Count = (Get-ChildItem -LiteralPath $Album.Fullname -file -recurse | Where-Object { $global:MaskCover -contains $_.Extension } | group-object -property directoryname | Measure-Object).count - $RepA_Count
		# on compte le nombre de fichiers images
		$Pics_Count = (Get-ChildItem -LiteralPath $Album.Fullname -file -recurse | Where-Object { $global:MaskCover -contains $_.Extension }).count;
		# on regarde si fichier cover de present
		$List_Cover = (Get-ChildItem -LiteralPath $album.Fullname -file -recurse | Sort-Object Name | Where-Object { $global:CoverAlbum -contains $_.name })
		if ($List_Cover){
			# on prend la premi�re trouv�e
			$Albm_Cover = $List_Cover[0].FullName
		} Else {
			# si 1 image, c'est la cover ?
			If ($Pics_Count -eq 1){
				$Albm_Cover = (Get-ChildItem -LiteralPath $Album.Fullname -file -recurse | Where-Object { $global:MaskCover -contains $_.Extension } | Select-Object FullName)[0].FullName
			} Else {
				$Albm_Cover = "No Picture"
			}
		}	
		# on regarde le format audio en prenant l'extension des fichiers audios
		Get-ChildItem -LiteralPath $Album.Fullname -file -recurse | Where-Object { $global:MaskMusic -contains $_.Extension } | Select -first 1 | Foreach-Object {$Audi_Type =($_.Extension).replace('.','').ToUpper()} ;
		# on compte la taille de l'album en Mo
		$Albm_Size = 0;
		Get-ChildItem -LiteralPath $Album.Fullname -file -recurse | Foreach-Object { $Albm_Size += $_.length } ;
		$Albm_Size /= (1024*1024);
		$Albm_Size = [math]::Round($Albm_Size,0);
		# on regarde si fichier(s) cue
		$Cues_Count = (Get-ChildItem -LiteralPath $Album.Fullname -file -recurse | Where-Object { @(".cue") -contains $_.Extension }).count;
		# on construit le MD5 avec le nom de l'album
		$Albm_IDMD5 = [System.Web.Security.FormsAuthentication]::HashPasswordForStoringInConfigFile($Album.Name, "MD5")
		
		##################### ANALYSE
		# c'est un double ?
		# > si audio dans des sous-r�pertoire et pas dans la racine alors oui
		If ($AudR_Count -eq 0){
			# nombre de cd = nombre de r�pertoire audio
			$NbCD_Count = $RepA_Count;
		} Else {
			# on regarde pas si 201,202,203,204... dans la racine
			$NbCD_Count = 1;
		}
		# calcul pivot analyse cue ou tag
		If ($Cues_Count -ge	 $Audi_Count) {
			$Tags_Type = 'CUE';
		} Else {
			$Tags_Type = 'TAG';
		}
		# LABEL/ISRC
		$Position1 = $Album.Fullname.Split("\")[5];
		$Position2 = $Album.Fullname.Split("\")[6];
		If (($Position1 -match 'label') -and (($Album.Name).StartsWith('['))){
			$LABEL = $Position2;
			$ISRC = ($Album.Name).Split(']')[0].Split('[')[1];
		} Else {
			$LABEL = $ISRC = '';
		}
		# YEAR
		$CleanAlbum = Get-CleanAlbumName -Album $Album.Name
		If ($CleanAlbum.Substring($CleanAlbum.length-6,6) -match "^[(][0-9][0-9][0-9][0-9][)]"){
			$YEAR = $CleanAlbum.Substring($CleanAlbum.length-5,5).Split(')')[0];
		} Else {
			$YEAR = '????';
		}
		# CATEGORY
		If ($Category -eq ""){
			$Category = $Album.Fullname.Split("\")[4];
		}
		##################### RESULTAT
		$AnalyseAlb = New-Object PsObject -property @{	 'ID_CD' = 0 ;
														 'MD5' = $Albm_IDMD5;
														 'Category' = $Category
														 'Family' =	 $Family;
														 'Position1' = $Position1;
														 'Position2' = $Position2;
														 'Name' = $Album.Name;
														 'Label' = $LABEL;
														 'ISRC' = $ISRC;
														 'Year' = $Year;
														 'Qty_CD' = $NbCD_Count;
														 'Qty_Cue' = $Cues_Count;
														 'Qty_CueERR' = $CueR_Count;
														 'Qty_repMusic' = $RepA_Count;
														 'Qty_Tracks' = 0;
														 'Qty_audio' = $Audi_Count;
														 'Typ_Audio' = $Audi_Type;
														 'Qty_repCover' = $RepC_Count;
														 'Qty_covers' = $Pics_Count;
														 'Cover' = $Albm_Cover;
														 'Path' = $Album.Fullname;
														 'Size' = $Albm_Size;
														 'Duration' = 0;
														 'Length' = '00:00:00';
														 'Typ_Tag' = $Tags_Type;
														 'Date_Insert' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss");
														 'Date_Modifs' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss");
														 'RHDD_Modifs' = ($Album.LastWriteTime).ToString("yyyy-MM-dd HH:mm:ss");
														 'Statut' = '##';
													};
		Return (@()+$AnalyseAlb);
	}
	catch [exception]{
		$ErrorMessage = $_.Exception.Message
		$FailedItem = $_.Exception.ItemName
		Write-Host $ErrorMessage
		Write-Host $FailedItem
		Write-Host -foregroundcolor "yellow" -NoNewLine ('Get-AnalyseAlb'+$Album.Name);
		Anno-toMySQL -MySqlCon $MySqlCon -ID_CD ($global:cptIDCD+1) -Path $Album.Fullname -Mess 'Invalid Analyse Album [Get-AnalyseAlb]' -Code 'TAG';
	}	
}


# regarde si un album existe dans la base
Function Get-AlbumMysql{
	param ([parameter(Mandatory = $true)][int] $Album_IDCD)
	
	$reqStr	 = "SELECT * FROM $Tbl_Albums WHERE ID_CD = $Album_IDCD;";
	$Rows = Execute-MySQLQuery -MySqlCon $MySqlCon -requete $reqStr;
	
	Return $Rows[0];
}


# traite le nom de l'album
Function Get-CleanAlbumName{
	param([Parameter(Mandatory=$true)][string]$Album)
	
	If ($Album.startswith('[')){
		# label : trt sp�cial
		$Final = $Album.Replace("_"," ").Replace("--","-")
	} Else {
		# on remplace _ et .
		$Final = $Album.Replace("-psy-music.ru","").Replace("_"," ").Replace("."," ").Replace("--","-")
		# on decoupe � chaque tiret
		$tab = $Final.Split("-")
		# en fonction du nombre de bouts
		Switch ($tab.count){
			# format 1 tirets artist-album
			2  { $Final = ($tab[0]).Trim() + " - " + ($tab[1]).Trim() }
			# format 2 tirets artist-album-ann�e
			3  { $Final = ($tab[0]).Trim() + " - " + ($tab[1]).Trim() + " (" + ($tab[2]).Trim() + ")" }
			# format 3 tirets artist-album-ann�e-xxx
			4  { $Final = ($tab[0]).Trim() + " - " + ($tab[1]).Trim() + " (" + ($tab[2]).Trim() + ")" }
			# format 4 tirets artist-album-xxx-annnee-xxx
			5  { $Final = ($tab[0]).Trim() + " - " + ($tab[1]).Trim() + " (" + ($tab[3]).Trim() + ")" }
			# format 5 tirets artist-album-label-xxx-annnee-xxx
			6  { $Final = "[" + ($tab[2]).Trim() + "] " + ($tab[0]).Trim() + " - " + ($tab[1]).Trim() + " (" + ($tab[4]).Trim() + ")" }
		}
		$Final = $Final.Trim()
	}
	# traitement sp�ciaux year
	If (!($Final.EndsWith(")"))){
		$year = $Final.substring($Final.length - 4, 4)
		If (IsNumeric($year)){
			# rajout parenth�ses
			$Final = $Final.substring(0,$Final.length - 4)+ "(" + $year + ")" 
		}
	}
	Return $Final.Trim()
}


Function IsNumeric($value) {
# This function will test if a string value is numeric
	Return ($($value.Trim()) -match "^[-]?[0-9.]+$")
}


# regarde si un album existe dans la base
Function Get-AlbumExist{
	param ([parameter(Mandatory = $true)][PSObject] $AlbumExist)

	[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null;
		   
	# on regarde si l'album existe dans la base via son MD5
	$Albm_IDMD5 = [System.Web.Security.FormsAuthentication]::HashPasswordForStoringInConfigFile($AlbumExist.Name, "MD5");
	$AlbumPresent = ($global:DBALBUMS | Where-Object {($_.MD5 -eq $Albm_IDMD5) -and ($_.path -eq $AlbumExist.Fullname)});
	If ($AlbumPresent){
		$AlbumPresent = $AlbumPresent[0];
	}
	Return $AlbumPresent;
}


# extract picture from TAG File
Function Get-CoverFromTag{
	param ([parameter(Mandatory = $true)][string] $Coverpath)
	
	[system.reflection.assembly]::loadfrom($global:FileDllTag) | Out-Null
	$FileTAG = (Get-ChildItem -LiteralPath $Coverpath -file -recurse | Where-Object { $global:MaskMusic -contains $_.Extension })[0]

	# on prend le tag
	try{
		$mediaTAG = [taglib.file]::create($FileTAG.FullName);
	}
	catch [exception]{
		Write-Host -foregroundcolor "yellow" -NoNewLine '#CoverFromTag';
		Anno-toMySQL -MySqlCon $MySqlCon -ID_CD ($global:cptIDCD+1) -Path $FileTAG.DirectoryName -Mess $messAno -Code 'TAG';
	}
	try{
		# si tag image de pr�sent
		if ($mediaTAG.tag.pictures.length -gt 0){
			Write-Host	-foregroundcolor "magenta" ("`r`n"+"		  | Extraction Cover :"+$FileTAG.DirectoryName+"\cover.jpg");
			Set-Content -LiteralPath ($FileTAG.DirectoryName+"\cover.jpg") -Value $mediaTAG.tag.pictures.Data -Encoding Byte;
		} 
	}
	catch [exception]{
		Write-Host -foregroundcolor "yellow" -NoNewLine '#CoverFromTagLenght';
		$artist = ($mediaTAG.Tag.Artists -join " ");
		$album = $mediaTAG.Tag.Album;
		$cover = $FileTAG.DirectoryName+"\cover.jpg"
		$messAno = "no cover tag and file, cmd:""$global:AlBumArtDownloader""  /artist ""$artist"" /album ""$album"" /path ""$cover"" /autoclose";
		Anno-toMySQL -MySqlCon $MySqlCon  -ID_CD ($global:cptIDCD+1) -Path $FileTAG.DirectoryName -Mess $messAno -Code 'COV';
	}
}


# propri�t� d'un album via ses tags
Function Get-ListeTag{
	param ([parameter(Mandatory = $true)][PSObject] $AlbumTAG)

	[system.reflection.assembly]::loadfrom($global:FileDllTag) | Out-Null
	
	$ListeTacks = @();
	$files = Get-ChildItem -LiteralPath $AlbumTAG.Path -file -recurse | Sort-Object Name | Where-Object { $MaskMusic -contains $_.Extension }
	ForEach ($file in $files){
		# on prend le tag
		try{
			$media = [taglib.file]::create($file.FullName);
		}
		catch [exception]{
			Write-Host -foregroundcolor "yellow" -NoNewLine ('#ListeTag'+$file.FullName);
			Anno-toMySQL -MySqlCon $MySqlCon  -ID_CD ($global:cptIDCD+1) -Path $file.DirectoryName -Mess 'ListeTag: Invalid Audio File'+$file.FullName -Code 'TAG';
		}
		# on ajoute la ligne des propri�t�s du track
		$global:cptIDTK++;
		$ts = New-TimeSpan -Seconds $media.properties.duration.totalseconds
		$TAG_Disc = [string]$media.Tag.Disc;
		If ($AlbumTAG.Qty_Cd -eq 1){
			If ($media.Tag.Disc -gt 0){
				$ODR_Track = $TAG_Disc+'-'+("{0:00}" -f $media.Tag.Track);
			} Else {
				$ODR_Track = ("{0:00}" -f $media.Tag.Track);
			}
		} Else {
			If ($media.Tag.Disc -eq 0){
				# correction tag via r�pertoire
				$REP_Disc = $file.DirectoryName.replace($AlbumTAG.Path,'').replace('\','')
				# find numbers disc
				$TAG_Disc = $REP_Disc -replace '\D+(\d+)\D*','$1'
				If ($REP_Disc -eq $TAG_Disc){
					$TAG_Disc = $REP_Disc.substring($REP_Disc.length-4,4).replace(' ','_')
				}
			}
			$ODR_Track = $TAG_Disc+'-'+("{0:00}" -f $media.Tag.Track);
		}
		$colonnes = New-Object PsObject -property @{'ID_CD' = $AlbumTAG.Id_CD;
													'ID_TRACK' = $global:cptIDTK;
													'Family' = $AlbumTAG.Family;
													'Category' = $file.DirectoryName.Split("\")[4];
													'Position1' = $file.DirectoryName.Split("\")[5];
													'Position2' = $file.DirectoryName.Split("\")[6];
													'REP_Album' = $AlbumTAG.Path;
													'REP_Track' = $file.DirectoryName;
													'FIL_Track' = $file.Name;
													'TAG_Exten' = $media.Properties.Description;
													'TAG_Album' = $media.Tag.Album; 
													'TAG_Albumartists' = ($media.Tag.albumartists -join " ");
													'TAG_Year' = $media.Tag.Year; 
													'TAG_Disc' = $TAG_Disc;
													'TAG_Track' = ("{0:00}" -f $media.Tag.Track); 
													'ODR_Track' = $ODR_Track;
													'TAG_Artists' = ($media.Tag.Artists -join " ");
													'TAG_Title' = $media.Tag.Title;
													'TAG_Genres' = ($media.Tag.Genres -join " ");
													'TAG_Duration' = $media.properties.duration.totalseconds;
													'TAG_length' = ('{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds);
													'Date_Insert' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss");
													'Statut' = 'NEW';
												}
		$ListeTacks += $colonnes;
	}		   
	Return (@()+$ListeTacks);
}


# propri�t� d'un album via ses cue
Function Get-ListeCue{
	param ([parameter(Mandatory = $true)][PSObject] $AlbumCue)

	[system.reflection.assembly]::loadfrom($global:FileDllTag) | Out-Null
	
	$cpt = 0
	$ListTracks = @();
	$files = Get-ChildItem -LiteralPath $AlbumCue.Path -file -recurse | Where-Object { @(".cue") -contains $_.Extension };
	ForEach ($file in $files){
		If (Test-Cue -FileCue $file -AlbCue $AlbumCue) {
			<#REM GENRE Reggae
			REM DATE 1981
			REM DISCID DA0B4210
			REM COMMENT "ExactAudioCopy v1.0b3"
			PERFORMER "Jennifer Lara"
			TITLE "Studio One Presents Jennifer Lara"
			FILE "Jennifer Lara - Studio One Presents Jennifer Lara.flac" WAVE#>
			$TAG_Album = Get-Content -literalpath $file.fullname | Where-Object {$_.StartsWith('TITLE')};
			if ($TAG_Album){
				$TAG_Album = $TAG_Album.split('"')[1];
			}
			$TAG_FormatArtists = Get-Content -literalpath $file.fullname | Where-Object {$_.StartsWith('PERFORMER')};
			if ($TAG_FormatArtists){
				$TAG_FormatArtists = $TAG_FormatArtists.split('"')[1];
			}
			$TAG_Year = Get-Content -literalpath $file.fullname | Where-Object {$_.StartsWith('REM DATE')};
			if ($TAG_Year){
				$TAG_Year = $TAG_Year.replace('REM DATE ','');
			}
			$TAG_Genre = Get-Content -literalpath $file.fullname | Where-Object {$_.StartsWith('REM GENRE')};
			if ($TAG_Genre){
				$TAG_Genre = $TAG_Genre.replace('REM GENRE ','');
			}
			$FIL_Track = (Get-Content -literalpath $file.fullname | Where-Object {$_.StartsWith('FILE')}).split('"')[1];
			# on regarde le format audio en prenant l'extension des fichiers audios
			$Audi_Type = $AlbumCue.Typ_Audio;
			# analyse Cue
			$cue = Get-Content -literalpath $file.fullname;
			$CUM_duration = 0;
			ForEach ($line in $cue){
				if ($line.StartsWith('FILE ')) {
					$FIL_Track = $line.split('"')[1];
				}
				if ($line -match 'TRACK ') {
					$TAG_Track = $line.replace('TRACK','').replace('AUDIO','').trim();
				}
				if ($line -match 'TITLE ') {
					$TAG_Title = $line.split('"')[1];
				}
				if ($line -match 'PERFORMER ') {
					$TAG_Artists = $line.split('"')[1];
				}
				if ($line -match 'INDEX 01') {
					$TAG_length = $line.replace('INDEX 01 ','').trim().split(":");
					$TAG_duration = [int]$TAG_length[0]*60+[int]$TAG_length[1];
					$TAG_duration = $TAG_duration - $CUM_duration;
					$CUM_duration += $TAG_duration
					$global:cptIDTK++;
					If ($AlbumCue.Qty_Cd -eq 1){
						$ODR_Track = ("{0:00}" -f $TAG_Track); 
						$TAG_Disc = $AlbumCue.Qty_Cd;
					} Else {
						$REP_Disc = $file.DirectoryName.replace($AlbumCue.Path,'').replace('\','')
						$TAG_Disc = $REP_Disc -replace '\D+(\d+)\D*','$1'
						If ($REP_Disc -eq $TAG_Disc){
							$TAG_Disc = $REP_Disc.substring($REP_Disc.length-4,4).replace(' ','_')
						}
						$ODR_Track = $TAG_Disc+'-'+("{0:00}" -f $TAG_Track);
					}
					$colonnes = New-Object PsObject -property @{'ID_CD' = $AlbumCue.Id_CD;
																'ID_TRACK' = $global:cptIDTK;					
																'Family' = $AlbumCue.Family;
																'Category' = $AlbumCue.Category;
																'Position1' = $File.DirectoryName.Split("\")[5];
																'Position2' = $File.DirectoryName.Split("\")[6];
																'REP_Album' = $AlbumCue.Path;
																'REP_Track' = $file.DirectoryName;
																'FIL_Track' = $FIL_Track;
																'TAG_Exten' = $Audi_Type;
																'TAG_Album' = $TAG_Album; 
																'TAG_Albumartists' = $TAG_FormatArtists;
																'TAG_Year' = $TAG_Year; 
																'TAG_Disc' = $TAG_Disc;
																'TAG_Track' = ("{0:00}" -f $TAG_Track); 
																'ODR_Track' = $ODR_Track;
																'TAG_Artists' = $TAG_Artists;
																'TAG_Title' = $TAG_Title;
																'TAG_Genres' = $TAG_Genre;
																'TAG_Duration' = 0;
																'TAG_length' = $TAG_length;
																'Date_Insert' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss");
																'Statut' = 'NEW';
															}
					$ListTracks += $colonnes
					if ($cpt -ne 0) {
						# on renseigne la dur�e du precedent track
						$ListTracks[($cpt-1)].TAG_Duration = $TAG_duration;
						$ts = New-TimeSpan -Seconds $TAG_duration;
						$ListTracks[($cpt-1)].TAG_length = ('{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds);
					}
					$cpt++
				}
			}
			# dur�e pour le dernier track via dur�e total du fichier
			try{
				If ($FIL_Track.Substring($FIL_Track.Length-3,3).ToUpper() -eq 'WAV') {
					$FIL_Track = $FIL_Track.Substring(0,$FIL_Track.Length-3)+$Audi_Type;
				} Else {
					
				}
				$media = [taglib.file]::create($file.DirectoryName+"\"+$FIL_Track);
			}
			catch [exception]{
				Write-Host -foregroundcolor "yellow" -NoNewLine 'Get-ListeCue';
				Anno-toMySQL -MySqlCon $MySqlCon -ID_CD $Album_Result.ID_CD -Path $file.FullName -Mess 'Invalid Audio File' -Code 'TAG';
			}
			If ($Audi_Type -eq 'APE'){
				$TAG_totalseconds = $media.properties.duration.hours*3600+$media.properties.duration.Minutes*60+$media.properties.duration.Seconds;
			} Else {
				$TAG_totalseconds = $media.properties.duration.totalseconds;
			}
			$ListTracks | % { $_.TAG_Exten=$media.Properties.Description};
			$TAG_duration = [math]::round(($TAG_totalseconds - $CUM_duration),0);
			$ListTracks[($cpt-1)].TAG_Duration = $TAG_duration;
			$ts = New-TimeSpan -Seconds $TAG_duration;
			$ListTracks[($cpt-1)].TAG_length = ('{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds);
		}
	}
	Return (@()+$ListTracks);
}


# test un fichier .cue validit� des fichiers + rajout de l'ann�e
Function Test-Cue{
	param ([parameter(Mandatory = $true)][PSObject] $FileCue,
		   [parameter(Mandatory = $true)][PSObject] $AlbCue,
		   [parameter(Mandatory = $false)][Switch] $Correction)
	
	If ($Correction){
		$TAG_Year = '';
		$TAG_Year += Get-Content -literalpath $FileCue.Fullname | Where-Object {$_.StartsWith('REM DATE')};
		If ($TAG_Year){
			$TAG_Year = $TAG_Year.replace('REM DATE ','');
		}
		# Ann�e via dossier Albums
		If ((($AlbCue.Name).Substring(($AlbCue.Name).length-6,6)) -match "^[(][0-9][0-9][0-9][0-9][)]"){
			$YEAR =	 ($AlbCue.Name).Substring(($AlbCue.Name).length-5,5).Split(')')[0];
		} Else {
			$CleanAlbum = Get-CleanAlbumName -Album $AlbCue.Name
			If ($CleanAlbum.Substring($CleanAlbum.length-6,6) -match "^[(][0-9][0-9][0-9][0-9][)]"){
				$YEAR = $CleanAlbum.Substring($CleanAlbum.length-5,5).Split(')')[0];
			} Else {
				$YEAR = '????';
			}
		}	
		If (($TAG_YEAR -match "^\d{4}") -and ($YEAR -eq '????')){
			# ANNEE cue � raison
			Write-Host -foregroundcolor "yellow" -NoNewLine '';
			$messAno = "Probl�me ANNEE dossier ({0}) <> ANNEE cue ({1}) : {2} -> {3}" -f  $YEAR, $TAG_Year, $AlbCue.Name, $AlbCue.FullName;
			Anno-toMySQL -MySqlCon $MySqlCon  -ID_CD ($global:cptIDCD+1) -Path $AlbCue.FullName -Mess $messAno -Code 'CYE';
		} ElseIf ((!($TAG_Year)) -or ($TAG_Year -notmatch "^\d{4}")){
			# ANNEE dossier a raison
			$messAno = "Correction DATE manquante [REM DATE {0}] ANNEE dossier ({0}) <> ANNEE cue ({1}) : {2} -> {3}" -f  $YEAR, $TAG_Year, $AlbCue.Name, $AlbCue.FullName;
			Write-Host -foregroundcolor "magenta" ("`r`n"+' '*10+" | "+$messAno);
			$lines = Get-Content -LiteralPath $FileCue.Fullname;
			$lines = $lines | Where-Object {$_ -notmatch "^(REM DATE)"};
			$NewCue = $lines[0], "REM DATE $YEAR" , $lines[1..($lines.Length - 1)];
			$NewCue | Set-Content -LiteralPath $FileCue.Fullname -Force;
			$TAG_Year = $YEAR;
		}
		IF ($TAG_Year -ne $YEAR){
			Write-Host -foregroundcolor "yellow" -NoNewLine '#year';
			$messAno =	"ANNEE diff�rente entre cue ({0}) <> ANNEE dossier ({1}) : {2} -> {3}" -f  $TAG_Year, $YEAR, $AlbCue.Name, $AlbCue.FullName			
			Anno-toMySQL -MySqlCon $MySqlCon  -ID_CD ($global:cptIDCD+1) -Path $AlbCue.FullName -Mess $messAno -Code 'CYD';
		}
	}
	# test Fichier
	Get-ChildItem -LiteralPath $FileCue.DirectoryName -file -recurse | Where-Object { $global:MaskMusic -contains $_.Extension } | Select -first 1 | Foreach-Object {$Audi_Type =($_.Extension).replace('.','').ToUpper()} ;
	$files = Get-Content -literalpath $FileCue.Fullname | Where-Object {$_.StartsWith('FILE')}
	$cuetest = $true
	Foreach ( $file in $files ) {
		$cue = ($FileCue.DirectoryName) + "\" + $file.split("""")[1]
		If ($Cue.Substring($Cue.Length-3,3).ToUpper() -eq 'WAV'){# -or ($Cue.Substring($Cue.Length-3,3).ToUpper() -eq 'MP3')){
			$cue = $Cue.Substring(0,$Cue.Length-3)+$Audi_Type;
		}
		$cuetest = (Test-Path -literalpath $cue);
	}
	Return $cuetest
}


# test les fichiers .cue d'un album
Function Album-TestCues{
	param ([parameter(Mandatory = $true)][PSObject] $AlbCue )
	
	$Cues = Get-ChildItem -LiteralPath $AlbCue.Fullname -file -recurse | Where-Object { @('.cue') -contains $_.Extension };
	$CuesAlbum = 0;
	Foreach ( $Cue in $Cues ) {
		if (!(Test-Cue -FileCue $Cue -AlbCue $AlbCue -Correction)){
			$CuesAlbum++;
		}
	}
	Return $CuesAlbum;
}


# construction tableau compteur
Function Get-PSArrayTDC{
	param ([parameter(Mandatory = $true)][PSObject] $Collections,
		   [parameter(Mandatory = $true)][PSObject] $BASE,
		   [parameter(Mandatory = $true)][String] $TabName)

	[System.Collections.ArrayList]$Results = New-Object System.Collections.ArrayList($null)
	ForEach ($Collection in $Collections){
		$RLigne = [ordered]@{$TabName = $Collection;}
		$Families.GetEnumerator()  | ForEach { 
			$Family = $_.name;
			$RLigne.Add($Family,(($BASE	 | ? { ($_.Family -eq $Family) -and ($_.Category -eq $Collection) }) | Measure-Object).count);
		}
		$RLigne.Add('Total',(($BASE	 | ? { ($_.Category -eq $Collection) }) | Measure-Object).count);
		$Results.Add((New-Object PSObject -Property $RLigne))  | Out-Null	
	}
	# total BASE
	$RLigne = [ordered]@{$TabName = 'TOTAL';}
	$Families.GetEnumerator()  | ForEach { 
		$Family = $_.name;
		$RLigne.Add($Family,(($BASE	 | ? { ($_.Family -eq $Family) }) | Measure-Object).count);
	}					
	$RLigne.Add('Total',($BASE	| Measure-Object).count);
	$Results.Add((New-Object PSObject -Property $RLigne))  | Out-Null

	$Results = $Results	| Format-Table -Property @{Expression={local}},* -autoSize;
	Return $Results;
}


# open MySQL
Function Connect-MySQL{ 
	param ([parameter(Mandatory = $true)][string] $MySQLHost,
		   [parameter(Mandatory = $true)][string] $user,
		   [parameter(Mandatory = $true)][string] $password,
		   [parameter(Mandatory = $true)][string] $database,
		   [parameter(Mandatory = $true)][string] $port)

	[void][system.reflection.Assembly]::LoadWithPartialName("MySql.Data");
	try {
		$MySqlCon = New-Object MySql.Data.MySqlClient.MySqlConnection("server=$MySQLHost;port=$port;uid=$user;pwd=$password;database=$database;Connection Timeout=1200;Pooling=FALSE" ) 
		$MySqlCon.Open();
	} catch {
		Write-Verbose "Unable to connect to MySQL server...";
		Write-Verbose $_.Exception.GetType().FullName;
		Write-Verbose $_.Exception.Message;
		Break;
	}
	Return $MySqlCon 
}


# close MySQL
Function Disconnect-MySQL{ 
	param ([parameter(Mandatory = $true)][PSObject] $MySqlCon) 
	
	$MySqlCon.Close();
}


# Requete non SELECT
Function Execute-MySQLNonQuery{
	param ([parameter(Mandatory = $true)][PSObject] $MySqlCon,
		   [parameter(Mandatory = $true)][string] $Requete)
	try{		   
		$cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($Requete, $MySqlCon);
		$Rows = $cmd.ExecuteNonQuery();
		$cmd.Dispose();
		}
	catch [exception]{
		Write-Host -foregroundcolor "yellow" ("MySQLNonQuery Error :"+$Requete);
		Write-Warning "Error occured: $_"
	}	
	Return , $Rows;
} 


# Requete SELECT
Function Execute-MySQLQuery{
	param ([parameter(Mandatory = $true)][PSObject] $MySqlCon,
		   [parameter(Mandatory = $true)][string] $Requete)
		   
	$cmd = New-Object MySql.Data.MySqlClient.MySqlCommand($Requete, $MySqlCon);
	$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($cmd);
	$dataSet = New-Object System.Data.DataSet;
	$Tableau = @();
	$RecordCount = $dataAdapter.Fill($dataSet, "data");
	$cmd.Dispose();
	$Tableau = $dataSet.Tables["data"];
	If ($RecordCount -ne 0){
		$Colonnes = ($Tableau | Get-Member -MemberType Property).Name;
		$Tableau = $Tableau | SELECT $colonnes
	}
	Return ($Tableau);
}

# TDC
Function Get-MySQLTDC{
	param ([parameter(Mandatory = $true)][PSObject] $MySqlCon,
		   [parameter(Mandatory = $true)][String] $Group,
		   [parameter(Mandatory = $true)][String] $Column,
		   [parameter(Mandatory = $true)][String] $TableName,
		   [parameter(Mandatory = $false)][String] $TDCName=$TableName,
		   [parameter(Mandatory = $false)][String] $TDCSum="1",
		   [parameter(Mandatory = $false)][Switch] $LineSum)

	# Collections
	$reqStr = "SELECT ``$Column`` FROM $TableName GROUP BY ``$Column``;";
	$Result = Execute-MySQLQuery -MySqlCon $MySqlCon -requete $reqStr;
	$Columns = $Result.$Column;
	$RequTDC = "SELECT * FROM (SELECT ``$Group`` AS ``$TDCName``,";
	ForEach ($ReqCol In $Columns) {
		$RequTDC += "SUM(IF(``$Column`` = '$ReqCol',$TDCSum, 0)) AS ``$ReqCol``,";
	}
	$RequTDC += "SUM($TDCSum) AS ``Total`` FROM $TableName GROUP BY ``$Group`` ORDER BY ``$Group`` DESC) ALB";
	IF ($LineSum) {
		$RequTDC += " UNION SELECT 'TOTAL',";
		ForEach ($ReqCol In $Columns) {
			$RequTDC += "SUM(IF($Column = '$ReqCol', $TDCSum, 0)),";
		}
		$RequTDC += "SUM($TDCSum) FROM $TableName";
	}
	$Sorting = @() + $TDCName + $Columns + 'TOTAL'
	$Results = Execute-MySQLQuery -MySqlCon $MySqlCon -requete $RequTDC;
	Return ($Results | Select-Object -Property $Sorting | Format-Table -Property @{Expression={Dbase}},* -autoSize);
}


# Ecrire un tableau [array] dans une table mysql
Function ArrayToMySQL{
	param ([parameter(Mandatory = $true)][PSObject] $MySqlCon,
		   [parameter(Mandatory = $true)][PSObject] $TabPower,
		   [parameter(Mandatory = $true)][string] $TblMysql,
		   [parameter(Mandatory = $false)][Switch] $Truncate)

	IF ($Truncate){
		# Effacer Table
		$reqStr	 = "TRUNCATE TABLE $TblMysql;";
		$rows = Execute-MySQLNonQuery -MySqlCon $MySqlCon -requete $reqStr;
	}
	try{	
		# Write Array
		ForEach ($Record in $TabPower){
			# liste Colonnes
			$Colums = @();
			$TabPower[0] | Get-Member | ? MemberType -EQ NoteProperty | ForEach-Object { $Colums += $_.Name	};
			# on construit la requete
			$reqStr = '';
			$reqCol = "INSERT INTO $TblMysql (``";
			$reqVal = ") VALUES ('";
			ForEach ($Colum in $Colums){
				# colonnes 
				$reqCol += $Colum+"``,``";
				If (!($Record.$Colum)) {
					$ColVal='';
				} Else {
					# 2016-05-19 01:38:25 et 05/19/2016 01:38:24 
					$ColVal = ($Record.$Colum);
					If (($ColVal -match '(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})') -or ($ColVal -match '(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2}):(\d{2})')){
						$ColVal=(Get-Date ($Record.$Colum)).ToString("yyyyMMddHHmmss");
					} Else {
						# nettoyage string pour mysql
						[string]$ColVal = $ColVal -join " ";
						$ColVal = $ColVal.Replace("'", "''");
						$ColVal = $ColVal.Replace("\", "\\");
					}
				}
				$reqVal += $ColVal+"','";
			}
			$reqStr += $reqCol.Substring(0,$reqCol.Length-2);	
			$reqStr += $reqVal.Substring(0,$reqVal.Length-2)+");";
			$Rows = Execute-MySQLNonQuery -MySqlCon $MySqlCon -requete $reqStr;
		}		
	}
	catch [exception]{
		Write-Host -foregroundcolor "yellow" ("ArrayToMySQL Error colonne:"+$Colum+" "+$Record);
		Write-Host -foregroundcolor "yellow" ($reqStr);
		Write-Warning "Error occured: $_"
	}
}


# Write Cover
Function Cover-ToMySQL{
	param ([parameter(Mandatory = $true)][PSObject] $MySqlCon,
		   [parameter(Mandatory = $true)][string] $PathCover,
		   [parameter(Mandatory = $true)][string] $MD5)
	If (!($PathCover.startswith('No Picture'))){
		If ((Get-ChildItem -LiteralPath $PathCover).Length -gt 400000){
			$ResizeCov = ($env:TEMP+'\cover_resized.jpg');
			$TempflCov = ($env:TEMP+'\cover.jpg')
			Copy-Item -LiteralPath $PathCover -Destination $TempflCov -force
			Resize-Image -Height 400 -MaintainRatio -ImagePath $TempflCov
			$ImgBase64 = [Convert]::ToBase64String((Get-Content -LiteralPath $ResizeCov -Encoding byte));
			If (Test-Path $ResizeCov) { Remove-Item -literalPath $ResizeCov};
		} Else {
			$ImgBase64 = [Convert]::ToBase64String((Get-Content -LiteralPath $PathCover -Encoding byte));
		}
		$Requete = "DELETE FROM $Tbl_Covers WHERE ``MD5``= '$MD5'";
		$Result = Execute-MySQLQuery -MySqlCon $MySqlCon -requete $Requete;
		$Requete = "INSERT INTO $Tbl_Covers (``MD5``,``Cover64``) VALUES ('$MD5','$ImgBase64')";
		$Result = Execute-MySQLQuery -MySqlCon $MySqlCon -requete $Requete;
	}
}

# Write Cover
Function Covers-ToMySQL{
	param ([parameter(Mandatory = $true)][PSObject] $MySqlCon,
		   [parameter(Mandatory = $true)][string] $PathCover,
		   [parameter(Mandatory = $true)][string] $MD5,
		   [parameter(Mandatory = $false)][Switch] $Mini)
	If (!($PathCover.startswith('No Picture'))){
		# cover
		$ResizeCov = ($env:TEMP+'\cover_resized.jpg');
		$TempflCov = ($env:TEMP+'\cover-temp.jpg')
		Copy-Item -LiteralPath $PathCover -Destination $TempflCov -force
		If (!($Mini)){
			If ((Get-ChildItem -LiteralPath $PathCover).Length -gt 400000){
				Resize-Image -Height 400 -MaintainRatio -ImagePath $TempflCov
				$Cover = [Convert]::ToBase64String((Get-Content -LiteralPath $ResizeCov -Encoding byte));
			} Else {
				$Cover = [Convert]::ToBase64String((Get-Content -LiteralPath $TempflCov -Encoding byte));
			}
			If (Test-Path $ResizeCov) { Remove-Item -literalPath $ResizeCov};
			# sql
			$Requete = "DELETE FROM $Tbl_Covers WHERE ``MD5``= '$MD5'";
			$Result = Execute-MySQLQuery -MySqlCon $MySqlCon -requete $Requete;
			$Requete = "INSERT INTO $Tbl_Covers (``MD5``,``Cover64``) VALUES ('$MD5','$Cover')";
			$Result = Execute-MySQLQuery -MySqlCon $MySqlCon -requete $Requete;
		} 
		Resize-Image -Height 150 -Width 150 -ImagePath $TempflCov
		$CMini = [Convert]::ToBase64String((Get-Content -LiteralPath $ResizeCov -Encoding byte));
		If (Test-Path $ResizeCov) { Remove-Item -literalPath $ResizeCov};
		If (Test-Path $TempflCov) { Remove-Item -literalPath $TempflCov};
		# sql
		$Requete = "UPDATE $Tbl_Covers SET ``MiniCover64``='$CMini' WHERE ``MD5``= '$MD5'";
		$Result = Execute-MySQLQuery -MySqlCon $MySqlCon -requete $Requete;
		# test
		#$Content = [System.Convert]::FromBase64String($CMini)
		#Set-Content -Path ($env:TEMP+'\cover-essai.jpg') -Value $Content -Encoding Byte	
	}
}


# Write-Host Waiting
Function Super-Waiting{
	param ([parameter(Mandatory = $False)][Int32]  $Seconds=5,
		   [parameter(Mandatory = $False)][String] $Label='Waiting',
		   [parameter(Mandatory = $False)][Int32]  $Indent=6)

	$Seconds..0 | ForEach-Object{ Write-Host -nonewline ("`r"+' '*$Indent+"$Label $_`s"+'.'*$_+' '*$Seconds) ; Start-Sleep -Seconds 1 };
	Write-Host ("`r");
}


# write Anomalies Analyse
Function Anno-toMySQL{
	param ([parameter(Mandatory = $true)][PSObject] $MySqlCon,
		   [parameter(Mandatory = $false)][string] $ID_CD='0',
		   [parameter(Mandatory = $false)][string] $Path='',
		   [parameter(Mandatory = $false)][string] $Mess='',
		   [parameter(Mandatory = $false)][string] $Code='ERR',
		   [parameter(Mandatory = $false)][string] $Mode='AUTO')
	
	$TabErr = New-Object PsObject -property @{	'ID_CD' = $ID_CD;
												'Path' = $Path;
												'MESS' = $mess;
												'COD' = $Code;
												'MODE' = $Mode;
	}
	ArrayToMySQL -MySqlCon $MySqlCon -TabPower $TabErr -TblMysql $Tbl_Errors;
}


# resize picture
<#
.SYNOPSIS
   Resize an image
.DESCRIPTION
   Resize an image based on a new given height or width or a single dimension and a maintain ratio flag.
   The execution of this CmdLet creates a new file named "OriginalName_resized" and maintains the original
   file extension
.PARAMETER Width
   The new width of the image. Can be given alone with the MaintainRatio flag
.PARAMETER Height
   The new height of the image. Can be given alone with the MaintainRatio flag
.PARAMETER ImagePath
   The path to the image being resized
.PARAMETER MaintainRatio
   Maintain the ratio of the image by setting either width or height. Setting both width and height and also this parameter
   results in an error
.PARAMETER Percentage
   Resize the image *to* the size given in this parameter. It's imperative to know that this does not resize by the percentage but to the percentage of
   the image.
.EXAMPLE
   Resize-Image -Height 45 -Width 45 -ImagePath "Path/to/image.jpg"
.EXAMPLE
   Resize-Image -Height 45 -MaintainRatio -ImagePath "Path/to/image.jpg"
.EXAMPLE
   #Resize to 50% of the given image
   Resize-Image -Percentage 50 -ImagePath "Path/to/image.jpg"
.NOTES
   Written By:
   Christopher Walker
#>
Function Resize-Image() {
	[CmdLetBinding(
		SupportsShouldProcess=$true,
		PositionalBinding=$false,
		ConfirmImpact="Medium",
		DefaultParameterSetName="Absolute"
	)]
	Param (
		[Parameter(Mandatory=$True)]
		[ValidateScript({
			$_ | ForEach-Object {
				Test-Path $_
			}
		})][String[]]$ImagePath,
		[Parameter(Mandatory=$False)][Switch]$MaintainRatio,
		[Parameter(Mandatory=$False, ParameterSetName="Absolute")][Int]$Height,
		[Parameter(Mandatory=$False, ParameterSetName="Absolute")][Int]$Width,
		[Parameter(Mandatory=$False, ParameterSetName="Percent")][Double]$Percentage
	)
	Begin {
		If ($Width -and $Height -and $MaintainRatio) {
			Throw "Absolute Width and Height cannot be given with the MaintainRatio parameter."
		}
 
		If (($Width -xor $Height) -and (-not $MaintainRatio)) {
			Throw "MaintainRatio must be set with incomplete size parameters (Missing height or width without MaintainRatio)"
		}
 
		If ($Percentage -and $MaintainRatio) {
			Write-Warning "The MaintainRatio flag while using the Percentage parameter does nothing"
		}
	}
	Process {
		ForEach ($Image in $ImagePath) {
			$Path = (Resolve-Path $Image).Path
			#Add name modifier (OriginalName_resized.jpg)
			$OutputPath = $env:TEMP+'\cover_resized.jpg';
			$OldImage = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $Path
			$OldHeight = $OldImage.Height
			$OldWidth = $OldImage.Width
 
			If ($MaintainRatio) {
				$OldHeight = $OldImage.Height
				$OldWidth = $OldImage.Width
				If ($Height) {
					$Width = $OldWidth / $OldHeight * $Height
				}
				If ($Width) {
					$Height = $OldHeight / $OldWidth * $Width
				}
			}
 
			If ($Percentage) {
				$Percentage = ($Percentage / 100)
				$Height = $OldHeight * $Percentage
				$Width = $OldWidth * $Percentage
			}
 
			$Bitmap = New-Object -TypeName System.Drawing.Bitmap -ArgumentList $Width, $Height
			$NewImage = [System.Drawing.Graphics]::FromImage($Bitmap)
			 
			#Retrieving the best quality possible
			$NewImage.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
			$NewImage.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
			$NewImage.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
			 
			$NewImage.DrawImage($OldImage, $(New-Object -TypeName System.Drawing.Rectangle -ArgumentList 0, 0, $Width, $Height))
			If ($PSCmdlet.ShouldProcess("Resized image based on $Path", "saved to $OutputPath")) {
				$Bitmap.Save($OutputPath)
			}
			$OldImage.Dispose()
			$Bitmap.Dispose()
			$NewImage.Dispose()
		}
	}
}