package com.nugusauce.domain.media

import com.nugusauce.domain.member.Member
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint
import java.time.Instant

@Entity
@Table(
    name = "media_asset",
    uniqueConstraints = [
        UniqueConstraint(name = "uk_media_asset_provider_key", columnNames = ["provider", "provider_key"])
    ]
)
class MediaAsset(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0L,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id", nullable = false)
    val owner: Member,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    val provider: MediaProvider,

    @Column(name = "provider_key", nullable = false, length = 512)
    val providerKey: String,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    var status: MediaAssetStatus = MediaAssetStatus.PENDING_UPLOAD,

    @Column(nullable = false, length = 120)
    var contentType: String,

    @Column(nullable = false)
    var byteSize: Long,

    @Column(nullable = true)
    var width: Int? = null,

    @Column(nullable = true)
    var height: Int? = null,

    @Column(nullable = true)
    var attachedRecipeId: Long? = null,

    @Column(nullable = true)
    var attachedProfileMemberId: Long? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    init {
        require(providerKey.isNotBlank()) { "media provider key must not be blank" }
        require(contentType.isNotBlank()) { "media content type must not be blank" }
        require(byteSize > 0) { "media byte size must be positive" }
    }

    fun markVerified(
        contentType: String,
        byteSize: Long,
        width: Int?,
        height: Int?,
        verifiedAt: Instant = Instant.now()
    ) {
        require(status == MediaAssetStatus.PENDING_UPLOAD || status == MediaAssetStatus.VERIFIED) {
            "only pending or verified media can be verified"
        }
        require(byteSize > 0) { "verified byte size must be positive" }
        this.contentType = contentType
        this.byteSize = byteSize
        this.width = width
        this.height = height
        status = MediaAssetStatus.VERIFIED
        touch(verifiedAt)
    }

    fun attachToRecipe(recipeId: Long, attachedAt: Instant = Instant.now()) {
        require(status == MediaAssetStatus.VERIFIED || status == MediaAssetStatus.ATTACHED) {
            "only verified media can be attached"
        }
        require(attachedProfileMemberId == null) {
            "media is already attached to a profile"
        }
        require(attachedRecipeId == null || attachedRecipeId == recipeId) {
            "media is already attached to another recipe"
        }
        attachedRecipeId = recipeId
        status = MediaAssetStatus.ATTACHED
        touch(attachedAt)
    }

    fun attachToProfile(memberId: Long, attachedAt: Instant = Instant.now()) {
        require(status == MediaAssetStatus.VERIFIED || status == MediaAssetStatus.ATTACHED) {
            "only verified media can be attached"
        }
        require(attachedRecipeId == null) {
            "media is already attached to a recipe"
        }
        require(attachedProfileMemberId == null || attachedProfileMemberId == memberId) {
            "media is already attached to another profile"
        }
        attachedProfileMemberId = memberId
        status = MediaAssetStatus.ATTACHED
        touch(attachedAt)
    }

    fun detachFromProfile(memberId: Long, detachedAt: Instant = Instant.now()) {
        require(attachedRecipeId == null) {
            "recipe media cannot be detached from a profile"
        }
        require(attachedProfileMemberId == null || attachedProfileMemberId == memberId) {
            "media is attached to another profile"
        }
        attachedProfileMemberId = null
        status = MediaAssetStatus.VERIFIED
        touch(detachedAt)
    }

    val isAttached: Boolean
        get() = attachedRecipeId != null || attachedProfileMemberId != null

    private fun touch(at: Instant = Instant.now()) {
        updatedAt = at
    }
}
