#/usr/bin/bash
set -e

echo "[builder] Building as $GIT_NAME <$GIT_EMAIL>"
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

if [ -z "$GIT_UPSTREAM" ];then
  GIT_UPSTREAM="origin/develop"
fi

if [ -z "$DEBSIGN_KEYID" ]; then
  # Default ripple labs releng key
  export DEBSIGN_KEYID="494EC596"
fi

echo "[builder] Packages will be signed with $DEBSIGN_KEYID:"
gpg --list-keys $DEBSIGN_KEYID


if [ ! -f /root/build/rippled/SConstruct ];then
  mkdir -p /root/build/

  if [ -d /root/src/rippled ]; then
    GIT_REPO="/root/src/rippled"
  else
    GIT_REPO="git://github.com/ripple/rippled"
  fi

  echo "[builder] Cloning rippled"
  git clone $GIT_REPO /root/build/rippled
fi

cd /root/build/rippled
VERSION=$(git describe --abbrev=0 --tags $GIT_UPSTREAM)
DEB_VERSION=$(echo $VERSION | sed -e s/-/~/g)
echo "[builder] Latest upstream tag in $GIT_UPSTREAM is $VERSION"
echo "[builder] Deb package will be $DEB_VERSION"

echo "[builder] Merging into debian"
git checkout debian
git merge -X theirs $GIT_UPSTREAM

echo "[builder] Generating changelog"
gbp dch -R --commit --auto --upstream-tag=$VERSION

echo "[builder] Generating rippled_$DEB_VERSION.orig.tar.xz"
git archive $GIT_UPSTREAM --prefix=rippled-$DEB_VERSION/ | xz > ../rippled_$DEB_VERSION.orig.tar.xz

echo "[builder] Building package rippled-$DEB_VERSION"
dpkg-buildpackage
#git tag -s ubuntu/$VERSION -m '$DEB_VERSION built from $VERSION'

echo "[builder] Build complete. Pushing new tags and copying package output"
mkdir -p /root/src/rippled/build/deb/
rsync -avzP ../*.{deb,changes,dsc,tar.gz,tar.xz} /root/src/rippled/build/deb/
#git push --tags
