package org.example.deploymentlab1.repository;

import org.example.deploymentlab1.entity.Item;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ItemRepository extends JpaRepository<Item, Long> {
}
