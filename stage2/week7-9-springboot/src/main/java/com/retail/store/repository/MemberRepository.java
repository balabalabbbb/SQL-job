package com.retail.store.repository;

import com.retail.store.entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface MemberRepository extends JpaRepository<Member, String> {
    Optional<Member> findByPhone(String phone);

    @Modifying
    @Query("UPDATE Member m SET m.pointsBalance = m.pointsBalance + :points WHERE m.memberId = :memberId")
    int addPoints(String memberId, int points);
}
