package com.retail.store.service;

import com.retail.store.entity.Product;
import com.retail.store.exception.NotFoundException;
import com.retail.store.exception.ValidationException;
import com.retail.store.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProductService {
    private final ProductRepository productRepository;

    public List<Product> getAllProducts() {
        return productRepository.findAllWithCategory();
    }

    public Product getProduct(String productId) {
        return productRepository.findById(productId)
                .orElseThrow(() -> new NotFoundException("商品不存在"));
    }

    @Transactional
    public Product createProduct(Product product) {
        if (product.getProductId() == null || product.getProductId().isEmpty()) {
            throw new ValidationException("商品ID不能为空");
        }
        if (product.getProductName() == null || product.getProductName().isEmpty()) {
            throw new ValidationException("商品名称不能为空");
        }
        if (product.getSalePrice() != null && product.getSalePrice().signum() < 0) {
            throw new ValidationException("售价不能为负数");
        }
        if (productRepository.existsById(product.getProductId())) {
            throw new ValidationException("商品ID已存在");
        }
        if (product.getStatus() == null) {
            product.setStatus("在售");
        }
        log.info("创建商品: {} {}", product.getProductId(), product.getProductName());
        return productRepository.save(product);
    }

    @Transactional
    public Product updateProduct(String productId, Product product) {
        Product existing = getProduct(productId);
        existing.setProductName(product.getProductName());
        existing.setSalePrice(product.getSalePrice());
        existing.setPurchasePrice(product.getPurchasePrice());
        existing.setUnit(product.getUnit());
        existing.setCategoryId(product.getCategoryId());
        log.info("修改商品: {}", productId);
        return productRepository.save(existing);
    }

    @Transactional
    public void deleteProduct(String productId) {
        if (!productRepository.existsById(productId)) {
            throw new NotFoundException("商品不存在");
        }
        productRepository.deleteById(productId);
        log.info("删除商品: {}", productId);
    }
}
