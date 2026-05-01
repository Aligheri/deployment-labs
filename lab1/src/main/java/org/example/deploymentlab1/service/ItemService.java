package org.example.deploymentlab1.service;

import org.example.deploymentlab1.entity.Item;
import org.example.deploymentlab1.repository.ItemRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class ItemService {

    private final ItemRepository repository;

    public ItemService(ItemRepository repository) {
        this.repository = repository;
    }

    public List<Item> findAll() {
        return repository.findAll();
    }

    public Optional<Item> findById(Long id) {
        return repository.findById(id);
    }

    public Item create(String name, Integer quantity) {
        Item item = new Item();
        item.setName(name);
        item.setQuantity(quantity);
        return repository.save(item);
    }
}
