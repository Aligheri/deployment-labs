package org.example.deploymentlab1.controller;

import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/")
public class RootController {

    @GetMapping(produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> root() {
        String html = "<html><body>"
                + "<h1>mywebapp - Simple Inventory</h1>"
                + "<ul>"
                + "<li>GET /items - list all items</li>"
                + "<li>POST /items?name=&quantity= - create item</li>"
                + "<li>GET /items/{id} - get item by id</li>"
                + "</ul>"
                + "</body></html>";
        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(html);
    }
}
