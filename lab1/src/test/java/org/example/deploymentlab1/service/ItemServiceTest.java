package org.example.deploymentlab1.service;

import org.example.deploymentlab1.entity.Item;
import org.example.deploymentlab1.repository.ItemRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ItemServiceTest {

    @Mock
    private ItemRepository repository;

    @InjectMocks
    private ItemService itemService;

    @Test
    void findAll_emptyRepository_returnsEmptyList() {
        when(repository.findAll()).thenReturn(List.of());
        assertThat(itemService.findAll()).isEmpty();
    }

    @Test
    void findAll_withItems_returnsList() {
        Item item = new Item();
        item.setName("Desk");
        item.setQuantity(1);
        when(repository.findAll()).thenReturn(List.of(item));

        List<Item> result = itemService.findAll();
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getName()).isEqualTo("Desk");
    }

    @Test
    void findById_existingId_returnsItem() {
        Item item = new Item();
        item.setName("Chair");
        item.setQuantity(4);
        when(repository.findById(1L)).thenReturn(Optional.of(item));

        assertThat(itemService.findById(1L)).isPresent().contains(item);
    }

    @Test
    void findById_missingId_returnsEmpty() {
        when(repository.findById(99L)).thenReturn(Optional.empty());
        assertThat(itemService.findById(99L)).isEmpty();
    }

    @Test
    void create_savesItemWithNameAndQuantity() {
        Item saved = new Item();
        saved.setName("Monitor");
        saved.setQuantity(2);
        when(repository.save(any(Item.class))).thenReturn(saved);

        Item result = itemService.create("Monitor", 2);
        assertThat(result.getName()).isEqualTo("Monitor");
        assertThat(result.getQuantity()).isEqualTo(2);
        verify(repository).save(any(Item.class));
    }
}
