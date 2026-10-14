package com.retail.store;

import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class RetailStoreApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    private static MockHttpSession managerSession;
    private static MockHttpSession cashierSession;
    private static MockHttpSession customerSession;

    @Test
    @Order(1)
    void test01_managerLogin() throws Exception {
        String json = "{\"login_type\":\"employee\",\"account\":\"manager01\",\"password\":\"Manager@123\"}";
        var result = mockMvc.perform(post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andReturn();
        managerSession = (MockHttpSession) result.getRequest().getSession();
        System.out.println("1. 店长登录: PASS");
    }

    @Test
    @Order(2)
    void test02_productList() throws Exception {
        mockMvc.perform(get("/products/api/list").session(managerSession))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
        System.out.println("2. 商品列表查询: PASS");
    }

    @Test
    @Order(3)
    void test03_inventoryList() throws Exception {
        mockMvc.perform(get("/inventory/api/list").session(managerSession))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
        System.out.println("3. 库存列表查询: PASS");
    }

    @Test
    @Order(4)
    void test04_orderList() throws Exception {
        mockMvc.perform(get("/orders/api/list").session(managerSession))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
        System.out.println("4. 订单列表查询: PASS");
    }

    @Test
    @Order(5)
    void test05_addProduct() throws Exception {
        String json = "{\"productId\":\"PT001\",\"productName\":\"测试商品\",\"salePrice\":9.99,\"unit\":\"瓶\"}";
        mockMvc.perform(post("/products/api/add")
                .session(managerSession)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
        System.out.println("5. 商品新增: PASS");
    }

    @Test
    @Order(6)
    void test06_duplicateProductRejected() throws Exception {
        String json = "{\"productId\":\"PT001\",\"productName\":\"重复商品\",\"salePrice\":1.00}";
        mockMvc.perform(post("/products/api/add")
                .session(managerSession)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isBadRequest());
        System.out.println("6. 重复主键约束拒绝: PASS");
    }

    @Test
    @Order(7)
    void test07_updateProduct() throws Exception {
        String json = "{\"productId\":\"PT001\",\"productName\":\"测试商品-修改\",\"salePrice\":19.99,\"unit\":\"瓶\"}";
        mockMvc.perform(post("/products/api/update")
                .session(managerSession)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
        System.out.println("7. 商品修改: PASS");
    }

    @Test
    @Order(8)
    void test08_deleteProduct() throws Exception {
        mockMvc.perform(post("/products/api/delete/PT001").session(managerSession))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
        System.out.println("8. 商品删除: PASS");
    }

    @Test
    @Order(9)
    void test09_createOrder() throws Exception {
        String json = "{\"items\":[{\"productId\":\"P0001\",\"quantity\":1}],\"paymentMethod\":\"现金\",\"memberId\":\"M0001\"}";
        mockMvc.perform(post("/orders/api/create")
                .session(managerSession)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.orderId").exists());
        System.out.println("9. 创建订单(事务): PASS");
    }

    @Test
    @Order(10)
    void test10_invalidProductRejected() throws Exception {
        String json = "{\"items\":[{\"productId\":\"INVALID\",\"quantity\":1}],\"paymentMethod\":\"现金\"}";
        mockMvc.perform(post("/orders/api/create")
                .session(managerSession)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isNotFound());
        System.out.println("10. 非法外码拒绝: PASS");
    }

    @Test
    @Order(11)
    void test11_notLoggedInRejected() throws Exception {
        mockMvc.perform(get("/products/api/list"))
                .andExpect(status().isUnauthorized());
        System.out.println("11. 未登录拒绝: PASS");
    }

    @Test
    @Order(12)
    void test12_cashierLogin() throws Exception {
        String json = "{\"login_type\":\"employee\",\"account\":\"cashier01\",\"password\":\"Manager@123\"}";
        var result = mockMvc.perform(post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isOk())
                .andReturn();
        cashierSession = (MockHttpSession) result.getRequest().getSession();
        System.out.println("12. 店员登录: PASS");
    }

    @Test
    @Order(13)
    void test13_cashierPermissionDenied() throws Exception {
        String json = "{\"productId\":\"PT002\",\"productName\":\"越权商品\",\"salePrice\":1.00}";
        mockMvc.perform(post("/products/api/add")
                .session(cashierSession)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isForbidden());
        System.out.println("13. 店员越权拒绝(商品管理): PASS");
    }

    @Test
    @Order(14)
    void test14_memberLogin() throws Exception {
        String json = "{\"login_type\":\"member\",\"phone\":\"13800138001\"}";
        var result = mockMvc.perform(post("/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isOk())
                .andReturn();
        customerSession = (MockHttpSession) result.getRequest().getSession();
        System.out.println("14. 会员登录: PASS");
    }

    @Test
    @Order(15)
    void test15_customerPermissionDenied() throws Exception {
        String json = "{\"productId\":\"PT003\",\"productName\":\"越权商品\",\"salePrice\":1.00}";
        mockMvc.perform(post("/products/api/add")
                .session(customerSession)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
                .andExpect(status().isForbidden());
        System.out.println("15. 顾客越权拒绝: PASS");
    }
}
