#!/bin/bash

TEMP_PARENT_PATH="/Users/erwin/temp"
TEMP_PATH=`mktemp -d ${TEMP_PARENT_PATH}/publish-XXXXXX` || exit -1

echo "Output to" $TEMP_PATH

if [ $# -ne "3" ]
then
  echo "Script requires three arguments."
  exit -1
fi

SOURCE_TGZ=$1
APP_PATH=$2
DEST_PATH=$3

TMP=${SOURCE_TGZ##*/}
TMP=${TMP#GrandPerspective-}
VERSION_ID=${TMP%-src.tgz}

echo "Version" $VERSION_ID

OUTER_DIR=GrandPerspective-${VERSION_ID}
OUTER_DIR_PATH=$TEMP_PATH/$OUTER_DIR
OUT_DMG_FILE=GrandPerspective-${VERSION_ID}.dmg

echo "Extracting source archive"
tar xzf $SOURCE_TGZ -C $TEMP_PATH

rm -rf $OUTER_DIR_PATH/src

echo "Copying application"
mkdir $OUTER_DIR_PATH/GrandPerspective.app
tar cf - -C ${APP_PATH} . --exclude "CLASSES.NIB" --exclude "INFO.NIB" --exclude "nl.lproj" | tar xf - -C $OUTER_DIR_PATH/GrandPerspective.app

# Create application DMG file.
#
pushd $DEST_PATH > /dev/null
/Users/Erwin/bin/buildDMG.pl -dmgName ${OUT_DMG_FILE%.dmg} -volSize 1 -compressionLevel 9 $OUTER_DIR_PATH/*.txt $OUTER_DIR_PATH/GrandPerspective.app
popd > /dev/null

echo rm -rf $TEMP_PATH
