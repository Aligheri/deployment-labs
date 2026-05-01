package org.example.deploymentlab1.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.example.deploymentlab1.entity.Item;
import org.example.deploymentlab1.service.ItemService;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/items")
public class ItemController {

    private final ItemService itemService;
    private final ObjectMapper objectMapper;

    public ItemController(ItemService itemService, ObjectMapper objectMapper) {
        this.itemService = itemService;
        this.objectMapper = objectMapper;
    }

    @GetMapping
    public ResponseEntity<String> getItems(@RequestHeader(value = "Accept", defaultValue = "application/json") String accept) {
        List<Item> items = itemService.findAll();
        if (accept.contains(MediaType.TEXT_HTML_VALUE)) {
            return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(renderItemListHtml(items));
        }
        try {
            List<Map<String, Object>> result = items.stream()
                    .map(i -> Map.<String, Object>of("id", i.getId(), "name", i.getName()))
                    .toList();
            return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(objectMapper.writeValueAsString(result));
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @PostMapping
    public ResponseEntity<String> createItem(
            @RequestParam String name,
            @RequestParam Integer quantity,
            @RequestHeader(value = "Accept", defaultValue = "application/json") String accept) {
        Item item = itemService.create(name, quantity);
        if (accept.contains(MediaType.TEXT_HTML_VALUE)) {
            return ResponseEntity.status(HttpStatus.CREATED).contentType(MediaType.TEXT_HTML)
                    .body("<html><body><p>Created item with id " + item.getId() + "</p></body></html>");
        }
        try {
            Map<String, Object> result = Map.of("id", item.getId(), "name", item.getName(), "quantity", item.getQuantity());
            return ResponseEntity.status(HttpStatus.CREATED).contentType(MediaType.APPLICATION_JSON).body(objectMapper.writeValueAsString(result));
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<String> getItem(
            @PathVariable Long id,
            @RequestHeader(value = "Accept", defaultValue = "application/json") String accept) {
        Item item = itemService.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Item not found"));
        if (accept.contains(MediaType.TEXT_HTML_VALUE)) {
            return ResponseEntity.ok().contentType(MediaType.TEXT_HTML).body(renderItemDetailHtml(item));
        }
        try {
            Map<String, Object> result = Map.of(
                    "id", item.getId(),
                    "name", item.getName(),
                    "quantity", item.getQuantity(),
                    "created_at", item.getCreatedAt().toString());
            return ResponseEntity.ok().contentType(MediaType.APPLICATION_JSON).body(objectMapper.writeValueAsString(result));
        } catch (Exception e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private String renderItemListHtml(List<Item> items) {
        StringBuilder sb = new StringBuilder("<html><body><table border=\"1\"><tr><th>id</th><th>name</th></tr>");
        for (Item item : items) {
            sb.append("<tr><td>").append(item.getId()).append("</td><td>").append(item.getName()).append("</td></tr>");
        }
        sb.append("</table></body></html>");
        return sb.toString();
    }

    private String renderItemDetailHtml(Item item) {
        return "<html><body>"
                + "<p>id: " + item.getId() + "</p>"
                + "<p>name: " + item.getName() + "</p>"
                + "<p>quantity: " + item.getQuantity() + "</p>"
                + "<p>created_at: " + item.getCreatedAt() + "</p>"
                + "</body></html>";
    }
}