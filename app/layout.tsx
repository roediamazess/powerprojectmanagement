import type { Metadata } from "next";
import Script from "next/script";
import SettingsPanel from "./SettingsPanel";
import "./globals.css";

export const metadata: Metadata = {
  title:
    "Management And Administration Website Templates | Fillow : Fillow Saas Admin Bootstrap 5 Template - Empowering Your Administration Work  | Dexignlabs",
  description:
    "Elevate your administrative efficiency and enhance productivity with the Fillow SaaS Admin Dashboard Template.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="shortcut icon" type="image/png" href="/images/favicon.png" />
        <link
          href="/vendor/bootstrap-select/css/bootstrap-select.min.css"
          rel="stylesheet"
        />
        <link href="/vendor/owl-carousel/owl.carousel.css" rel="stylesheet" />
        <link rel="stylesheet" href="/vendor/nouislider/nouislider.min.css" />
        <link href="/css/style.css" rel="stylesheet" />
      </head>
      <body suppressHydrationWarning>
        {children}
        <SettingsPanel />
        <Script id="hide-preloader" strategy="afterInteractive">{`(function () {
  function hide() {
    var el = document.getElementById("preloader");
    if (el && el.parentNode) el.parentNode.removeChild(el);
    document.body && document.body.classList && document.body.classList.remove("vh-100");
    var mw = document.getElementById("main-wrapper");
    if (mw && mw.classList) mw.classList.add("show");
  }
  if (document.readyState === "complete") {
    hide();
  } else {
    window.addEventListener("load", hide);
    setTimeout(hide, 2000);
  }
})();`}</Script>
        <Script
          src="/vendor/global/global.min.js"
          strategy="afterInteractive"
        />
        <Script
          src="/vendor/bootstrap-select/js/bootstrap-select.min.js"
          strategy="afterInteractive"
        />
        <Script src="/js/settings.js" strategy="afterInteractive" />
        <Script src="/vendor/counter/counter.min.js" strategy="afterInteractive" />
        <Script src="/vendor/counter/waypoint.min.js" strategy="afterInteractive" />
        <Script src="/vendor/apexchart/apexchart.js" strategy="afterInteractive" />
        <Script
          src="/vendor/chart-js/chart.bundle.min.js"
          strategy="afterInteractive"
        />
        <Script
          src="/vendor/peity/jquery.peity.min.js"
          strategy="afterInteractive"
        />
        <Script src="/js/dashboard/dashboard-1.js" strategy="afterInteractive" />
        <Script
          src="/vendor/owl-carousel/owl.carousel.js"
          strategy="afterInteractive"
        />
        <Script src="/js/custom.min.js" strategy="afterInteractive" />
        <Script src="/js/dlabnav-init.js" strategy="afterInteractive" />
        <Script src="/js/sidebar-right.js" strategy="afterInteractive" />
        <Script id="cards-center" strategy="afterInteractive">{`(function () {
  function run() {
    if (typeof window === "undefined") return;
    var jq = window.jQuery || window.$;
    if (!jq || !jq.fn || !jq.fn.owlCarousel) {
      setTimeout(run, 50);
      return;
    }
    function cardsCenter()
{
	/*  testimonial one function by = owl.carousel.js */
	jQuery('.card-slider').owlCarousel({
		loop:true,
		margin:0,
		nav:true,
		//center:true,
		slideSpeed: 3000,
		paginationSpeed: 3000,
		dots: true,
		navText: ['<i class="fas fa-arrow-left"></i>', '<i class="fas fa-arrow-right"></i>'],
		responsive:{
			0:{
				items:1
			},
			576:{
				items:1
			},	
			800:{
				items:1
			},			
			991:{
				items:1
			},
			1200:{
				items:1
			},
			1600:{
				items:1
			}
		}
	})
}

jQuery(window).on('load',function(){
	setTimeout(function(){
		cardsCenter();
	}, 1000); 
});
  }
  run();
})();`}</Script>
      </body>
    </html>
  );
}
