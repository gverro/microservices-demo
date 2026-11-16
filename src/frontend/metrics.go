// Copyright 2026 Kiratech challenge (fork of GoogleCloudPlatform/microservices-demo)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

// Kiratech: Prometheus metrics of the frontend. They are served on a separate port (METRICS_PORT), so /metrics
// is never published by the Ingress together with the shop. Without METRICS_PORT nothing changes (upstream behaviour).

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"
)

var (
	metricsRegistry = prometheus.NewRegistry()

	// Labels have a small, fixed set of values: the route is the template ("/product/{id}"), never the URL,
	// and unknown methods are grouped. Free-form values would create one time series per value.
	httpRequests = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "frontend_http_requests_total",
		Help: "HTTP requests served by the frontend, by method, route template and status code.",
	}, []string{"method", "route", "code"})

	httpDuration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "frontend_http_request_duration_seconds",
		Help:    "Time taken to serve an HTTP request, by method and route template.",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "route"})

	ordersPlaced = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "frontend_orders_placed_total",
		Help: "Orders completed successfully through the checkout.",
	})
)

func init() {
	metricsRegistry.MustRegister(httpRequests, httpDuration, ordersPlaced,
		collectors.NewGoCollector(),
		collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}))
}

// statusWriter remembers the status code written by the handler (200 if it only calls Write).
type statusWriter struct {
	http.ResponseWriter
	status int
}

func (w *statusWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func metricsMethod(method string) string {
	switch method {
	case http.MethodGet, http.MethodHead, http.MethodPost:
		return method
	}
	return "OTHER"
}

func routeTemplate(router *mux.Router, r *http.Request) string {
	var match mux.RouteMatch
	if router.Match(r, &match) && match.Route != nil {
		if tpl, err := match.Route.GetPathTemplate(); err == nil {
			return tpl
		}
	}
	return "unmatched"
}

// instrumentHTTP counts every request and observes its duration, labelled by the route of router.
func instrumentHTTP(router *mux.Router, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		route := routeTemplate(router, r)
		start := time.Now()
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, r)
		method := metricsMethod(r.Method)
		httpRequests.WithLabelValues(method, route, strconv.Itoa(sw.status)).Inc()
		httpDuration.WithLabelValues(method, route).Observe(time.Since(start).Seconds())
	})
}

// startMetricsServer serves /metrics on addr:port in the background.
func startMetricsServer(log logrus.FieldLogger, addr, port string) {
	m := http.NewServeMux()
	m.Handle("/metrics", promhttp.HandlerFor(metricsRegistry, promhttp.HandlerOpts{}))
	srv := &http.Server{Addr: addr + ":" + port, Handler: m, ReadHeaderTimeout: 5 * time.Second}
	go func() {
		log.Infof("serving metrics on %s:%s/metrics", addr, port)
		log.Fatal(srv.ListenAndServe())
	}()
}
