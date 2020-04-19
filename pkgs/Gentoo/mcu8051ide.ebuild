# Distributed under the terms of the GNU General Public License v2
# $Header: $

DESCRIPTION="Graphical IDE for microcontrollers based on 8051."
HOMEPAGE="http://www.moravia-microsystems.com/mcu-8051-ide/"
SRC_URI="http://www.moravia-microsystems.com/download/mcu8051ide/${PN}/${PN}/${PV}/${PF}.tar.gz"

LICENSE="GPLv2"
SLOT="0"
KEYWORDS="~alpha amd64 ~ia64 ~ppc ~sparc x86"

RDEPEND="
	>=x11-terms/rxvt-unicode-9.1
	>=dev-embedded/sdcc-2.5
	>=app-doc/doxygen-1.7
	>=dev-util/indent-2.2
	>=app-text/hunspell-1.3
	>=dev-tcltk/bwidget-1.8
	>dev-tcltk/itcl-3.3
	>=dev-lang/tcl-8.5.9
	>=dev-tcltk/tdom-0.8
	>=dev-tcltk/tcllib-1.11
	>=dev-lang/tk-8.5.9
	>=dev-tcltk/tkimg-1.4
	>=dev-tcltk/tclx-8.4
"
DEPEND="
	${RDEPEND}
	>=dev-util/cmake-2.8
"

src_unpack() {
	unpack ${A}
}

src_compile() {
	cd "${PF}"
	cmake -DCMAKE_INSTALL_PREFIX=/usr . || die "cmake failed"
	emake || die "emake failed"
}

src_install() {
	cd "${PF}"
	emake DESTDIR="${D}" install || die "Install failed"
}
