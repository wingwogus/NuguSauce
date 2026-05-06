package com.nugusauce.domain.consent

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.Instant

interface PolicyVersionRepository : JpaRepository<PolicyVersion, Long> {
    @Query(
        """
        select p
        from PolicyVersion p
        where p.required = true
          and p.activeFrom <= :now
        order by p.policyType asc, p.activeFrom desc, p.id desc
        """
    )
    fun findRequiredActiveAt(@Param("now") now: Instant): List<PolicyVersion>
}
