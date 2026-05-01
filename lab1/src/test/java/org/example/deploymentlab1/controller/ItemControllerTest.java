package org.example.deploymentlab1.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_EACH_TEST_METHOD)
class ItemControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void getItems_emptyList_returnsJson() throws Exception {
        mockMvc.perform(get("/items").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(content().string("[]"));
    }

    @Test
    void getItems_emptyList_returnsHtml() throws Exception {
        mockMvc.perform(get("/items").accept(MediaType.TEXT_HTML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
                .andExpect(content().string(containsString("<table")));
    }

    @Test
    void createItem_returnsJsonWithCreatedStatus() throws Exception {
        mockMvc.perform(post("/items")
                        .param("name", "Monitor")
                        .param("quantity", "3")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isCreated())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(content().string(containsString("Monitor")))
                .andExpect(content().string(containsString("\"quantity\":3")));
    }

    @Test
    void createItem_returnsHtmlWithCreatedStatus() throws Exception {
        mockMvc.perform(post("/items")
                        .param("name", "Keyboard")
                        .param("quantity", "5")
                        .accept(MediaType.TEXT_HTML))
                .andExpect(status().isCreated())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
                .andExpect(content().string(containsString("Created item")));
    }

    @Test
    void getItemById_returnsJsonItem() throws Exception {
        String body = mockMvc.perform(post("/items")
                        .param("name", "Laptop")
                        .param("quantity", "1")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse().getContentAsString();

        long id = objectMapper.readTree(body).get("id").asLong();

        mockMvc.perform(get("/items/{id}", id).accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Laptop")))
                .andExpect(content().string(containsString("created_at")));
    }

    @Test
    void getItemById_returnsHtmlItem() throws Exception {
        String body = mockMvc.perform(post("/items")
                        .param("name", "Mouse")
                        .param("quantity", "2")
                        .accept(MediaType.APPLICATION_JSON))
                .andReturn().getResponse().getContentAsString();

        long id = objectMapper.readTree(body).get("id").asLong();

        mockMvc.perform(get("/items/{id}", id).accept(MediaType.TEXT_HTML))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
                .andExpect(content().string(containsString("Mouse")));
    }

    @Test
    void getItemById_notFound_returns404() throws Exception {
        mockMvc.perform(get("/items/{id}", 999999L).accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    void getItems_afterCreate_containsItem() throws Exception {
        mockMvc.perform(post("/items")
                .param("name", "Chair")
                .param("quantity", "4")
                .accept(MediaType.APPLICATION_JSON));

        mockMvc.perform(get("/items").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString("Chair")));
    }
}
