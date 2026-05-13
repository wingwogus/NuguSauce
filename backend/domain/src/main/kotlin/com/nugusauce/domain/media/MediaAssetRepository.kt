package com.nugusauce.domain.media

import org.springframework.data.jpa.repository.JpaRepository

interface MediaAssetRepository : JpaRepository<MediaAsset, Long> {
    fun findAllByOwnerId(ownerId: Long): List<MediaAsset>
}
