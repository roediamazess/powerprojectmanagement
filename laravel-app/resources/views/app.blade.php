<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="csrf-token" content="{{ csrf_token() }}">

        <title inertia>{{ config('app.name', 'Power Project Management') }}</title>

        <link rel="preload" href="{{ asset('css/style.css') }}?v={{ @filemtime(public_path('css/style.css')) }}" as="style">
        <link href="{{ asset('vendor/bootstrap-select/css/bootstrap-select.min.css') }}" rel="stylesheet">
        <link href="{{ asset('vendor/owl-carousel/owl.carousel.css') }}" rel="stylesheet">
        <link rel="stylesheet" href="{{ asset('vendor/nouislider/nouislider.min.css') }}">
        <link href="{{ asset('vendor/fullcalendar/css/main.min.css') }}" rel="stylesheet">
        <link href="{{ asset('vendor/bootstrap-datepicker-master/css/bootstrap-datepicker.min.css') }}" rel="stylesheet">
        <link href="{{ asset('vendor/sweetalert2/sweetalert2.min.css') }}" rel="stylesheet">
        <link href="{{ asset('css/style.css') }}?v={{ @filemtime(public_path('css/style.css')) }}" rel="stylesheet">

        <style>
            /* Critical CSS to prevent FOUC */
            body[data-theme-version="dark"] {
                background-color: #1a1a2e !important;
                color: #e1e1e3 !important;
            }
            #preloader {
                height: 100%;
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                z-index: 999999;
                background-color: #fff;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            body[data-theme-version="dark"] #preloader {
                background-color: #1a1a2e;
            }
            .lds-ripple {
                display: inline-block;
                position: relative;
                width: 80px;
                height: 80px;
            }
            .lds-ripple div {
                position: absolute;
                border: 4px solid #886CC0;
                opacity: 1;
                border-radius: 50%;
                animation: lds-ripple 1s cubic-bezier(0, 0.2, 0.8, 1) infinite;
            }
            .lds-ripple div:nth-child(2) {
                animation-delay: -0.5s;
            }
            @keyframes lds-ripple {
                0% { top: 36px; left: 36px; width: 0; height: 0; opacity: 1; }
                100% { top: 0px; left: 0px; width: 72px; height: 72px; opacity: 0; }
            }
        </style>

        <!-- Scripts -->
        @routes
        @viteReactRefresh
        @vite(['resources/js/app.jsx'])
        @inertiaHead
    </head>
    <body>
        <div id="preloader">
            <div class="lds-ripple">
                <div></div>
                <div></div>
            </div>
        </div>

        @inertia

        <script src="{{ asset('vendor/global/global.min.js') }}"></script>
        <script src="{{ asset('vendor/bootstrap-select/js/bootstrap-select.min.js') }}"></script>
        <script src="{{ asset('vendor/counter/counter.min.js') }}"></script>
        <script src="{{ asset('vendor/counter/waypoint.min.js') }}"></script>
        <script src="{{ asset('vendor/apexchart/apexchart.js') }}"></script>
        <script src="{{ asset('vendor/chart-js/chart.bundle.min.js') }}"></script>
        <script src="{{ asset('vendor/peity/jquery.peity.min.js') }}"></script>
        <script src="{{ asset('vendor/owl-carousel/owl.carousel.js') }}"></script>
        <script src="{{ asset('vendor/draggable/draggable.js') }}"></script>
        <script src="{{ asset('vendor/fullcalendar/js/main.min.js') }}"></script>
        <script src="{{ asset('vendor/moment/moment.min.js') }}"></script>
        <script src="{{ asset('vendor/bootstrap-datepicker-master/js/bootstrap-datepicker.min.js') }}"></script>
        <script src="{{ asset('vendor/sweetalert2/sweetalert2.min.js') }}"></script>
        <script src="{{ asset('js/custom.js') }}?v={{ @filemtime(public_path('js/custom.js')) }}"></script>
        <script src="{{ asset('js/dlabnav-init.js') }}"></script>
        <script src="{{ asset('js/sidebar-right.js') }}"></script>
    </body>
</html>
