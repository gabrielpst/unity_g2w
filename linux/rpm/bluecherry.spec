Name:       g2w-monitor
Version:    1.1.0
Release:    1
Summary:    G2W Monitor - cliente de monitoramento de cameras
License:    GPL-3.0-only
Requires:   mpv, mpv-libs-devel
AutoReqProv: no

%define __os_install_post %{nil}

%description
Cliente de monitoramento de cameras da G2W Tecnologia. Versao modificada do Bluecherry Client (GPL v3).

%prep
# no source

%build
# no source

%install
export DONT_STRIP=1
mkdir -p %{buildroot}
cp -rf linux/debian/usr/ %{buildroot}

%files
FILES_HERE

%changelog
# no changelog