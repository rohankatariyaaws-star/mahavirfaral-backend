package com.ecommerce.service;

import com.ecommerce.exception.ResourceNotFoundException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public abstract class BaseService<T, ID> {
    
    protected abstract JpaRepository<T, ID> getRepository();
    protected abstract String getEntityName();

    public List<T> findAll() {
        return getRepository().findAll();
    }

    public Page<T> findAll(Pageable pageable) {
        return getRepository().findAll(pageable);
    }

    public Optional<T> findById(ID id) {
        return getRepository().findById(id);
    }

    public T getById(ID id) {
        return findById(id)
                .orElseThrow(() -> new ResourceNotFoundException(getEntityName(), "id", id));
    }

    public T save(T entity) {
        return getRepository().save(entity);
    }

    public T update(ID id, T entity) {
        if (!getRepository().existsById(id)) {
            throw new ResourceNotFoundException(getEntityName(), "id", id);
        }
        return getRepository().save(entity);
    }

    public void deleteById(ID id) {
        if (!getRepository().existsById(id)) {
            throw new ResourceNotFoundException(getEntityName(), "id", id);
        }
        getRepository().deleteById(id);
    }

    public boolean existsById(ID id) {
        return getRepository().existsById(id);
    }

    public long count() {
        return getRepository().count();
    }
}