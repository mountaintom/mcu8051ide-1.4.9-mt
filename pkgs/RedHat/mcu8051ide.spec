Name: mcu8051ide
Summary: IDE for MSC-51 based MCUs
Version: 0.0
Release: 0
License: GPLv2
Group: Development/Tools/IDE
Source: %{name}-%{version}.tar.gz
Requires: tcl >= 8.5.9, tk >= 8.5.9, bwidget >= 1.8, tclx >= 8.4, itcl >= 3.4, tdom >= 0.8, tcllib >= 1.6, tkimg >= 1.3, rxvt-unicode >= 8.3, sdcc, doxygen, indent, hunspell
Provides: mcu8051ide

BuildRoot: /var/tmp/%{name}-buildroot
Packager: Martin Ošmera <martin.osmera@moravia-microsystems.com>
Distribution: Fedora
Url: http://www.moravia-microsystems.com/mcu8051ide

%description
MCU 8051 IDE is integrated development enviroment for MCS-51 based microcontrollers. Supported programming languages are C and assembly. It has its own assembler and support for 2 external assemblers. For C language it uses the SDCC compiler.

%prep
rm -rf $RPM_BUILD_ROOT
mkdir $RPM_BUILD_ROOT

%setup -q

%build
CFLAGS="$RPM_OPT_FLAGS" CXXFLAGS="$RPM_OPT_FLAGS" \
cmake -DCMAKE_INSTALL_PREFIX=/usr .
make -j 2

%install
make DESTDIR=$RPM_BUILD_ROOT install

cd $RPM_BUILD_ROOT

find . -type d -fprint $RPM_BUILD_DIR/file.list.%{name}.dirs
find . -type f -fprint $RPM_BUILD_DIR/file.list.%{name}.files.tmp
find . -type l >> $RPM_BUILD_DIR/file.list.%{name}.files.tmp
sed 's/^\./\."/g;s/$/"/g' $RPM_BUILD_DIR/file.list.%{name}.files.tmp >  $RPM_BUILD_DIR/file.list.%{name}.files
sed '1,2d;s,^\.,\%attr(-\,root\,root) \%dir ,' $RPM_BUILD_DIR/file.list.%{name}.dirs > $RPM_BUILD_DIR/file.list.%{name}
sed 's,^\.,\%attr(-\,root\,root) ,' $RPM_BUILD_DIR/file.list.%{name}.files >> $RPM_BUILD_DIR/file.list.%{name}

%clean
rm -rf $RPM_BUILD_ROOT
rm -rf $RPM_BUILD_DIR/file.list.%{name}
rm -rf $RPM_BUILD_DIR/file.list.%{name}.files
rm -rf $RPM_BUILD_DIR/file.list.%{name}.dirs

%files -f ../file.list.%{name}

%defattr(-,root,root,0755)

%verifyscript
mcu8051ide --check-libraries
