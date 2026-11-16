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

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/client_golang/prometheus/testutil"
)

func testRouter() *mux.Router {
	r := mux.NewRouter()
	r.HandleFunc("/product/{id}", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) }).Methods(http.MethodGet)
	r.HandleFunc("/cart/checkout", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}).Methods(http.MethodPost)
	return r
}

func serve(h http.Handler, method, path string) {
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(method, path, nil))
}

func TestInstrumentHTTPLabels(t *testing.T) {
	httpRequests.Reset()
	httpDuration.Reset()
	router := testRouter()
	h := instrumentHTTP(router, router)

	serve(h, http.MethodGet, "/product/AAA")
	serve(h, http.MethodGet, "/product/BBB")
	serve(h, http.MethodPost, "/cart/checkout")
	serve(h, http.MethodGet, "/no-such-page")
	serve(h, "PATCH", "/product/AAA")

	cases := []struct {
		method, route, code string
		want                float64
	}{
		{"GET", "/product/{id}", "200", 2}, // one series for every product: the route template, not the URL
		{"POST", "/cart/checkout", "500", 1},
		{"GET", "unmatched", "404", 1},
		{"OTHER", "unmatched", "405", 1}, // unknown methods are grouped
	}
	for _, c := range cases {
		if got := testutil.ToFloat64(httpRequests.WithLabelValues(c.method, c.route, c.code)); got != c.want {
			t.Errorf("requests{%s,%s,%s} = %v, want %v", c.method, c.route, c.code, got, c.want)
		}
	}
	if n := testutil.CollectAndCount(httpRequests); n != len(cases) {
		t.Errorf("got %d request series, want %d", n, len(cases))
	}
	if n := testutil.CollectAndCount(httpDuration); n != 4 { // by method and route, no code
		t.Errorf("got %d duration series, want 4", n)
	}
}

func TestMetricsEndpoint(t *testing.T) {
	ordersPlaced.Add(1)
	rec := httptest.NewRecorder()
	promhttp.HandlerFor(metricsRegistry, promhttp.HandlerOpts{}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	body := rec.Body.String()
	for _, name := range []string{"frontend_orders_placed_total", "go_goroutines"} {
		if !strings.Contains(body, name) {
			t.Errorf("/metrics does not expose %s", name)
		}
	}
}
