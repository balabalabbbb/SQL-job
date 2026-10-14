package com.retail.store.service;

import com.retail.store.dto.LoginRequest;
import com.retail.store.entity.Employee;
import com.retail.store.entity.Member;
import com.retail.store.exception.AuthException;
import com.retail.store.exception.NotFoundException;
import com.retail.store.repository.EmployeeRepository;
import com.retail.store.repository.MemberRepository;
import jakarta.servlet.http.HttpSession;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {
    private final EmployeeRepository employeeRepository;
    private final MemberRepository memberRepository;

    public Map<String, Object> login(LoginRequest request, HttpSession session) {
        if ("employee".equals(request.getLoginType())) {
            return employeeLogin(request, session);
        } else if ("member".equals(request.getLoginType())) {
            return memberLogin(request, session);
        }
        throw new AuthException("无效的登录类型");
    }

    private Map<String, Object> employeeLogin(LoginRequest request, HttpSession session) {
        Employee emp = employeeRepository.findByLoginAccount(request.getAccount())
                .orElseThrow(() -> new AuthException("账号或密码错误"));

        if (!BCrypt.checkpw(request.getPassword(), emp.getLoginPassword())) {
            throw new AuthException("账号或密码错误");
        }

        if (!"在职".equals(emp.getEmployeeStatus())) {
            throw new AuthException("账号已停用");
        }

        session.setAttribute("userId", emp.getEmployeeId());
        session.setAttribute("userName", emp.getEmployeeName());
        session.setAttribute("userRole", emp.getRole());
        session.setAttribute("userType", "employee");

        Map<String, Object> result = new HashMap<>();
        result.put("userId", emp.getEmployeeId());
        result.put("userName", emp.getEmployeeName());
        result.put("userRole", emp.getRole());
        result.put("userType", "employee");
        log.info("员工登录成功: {} ({})", emp.getEmployeeName(), emp.getRole());
        return result;
    }

    private Map<String, Object> memberLogin(LoginRequest request, HttpSession session) {
        String phone = request.getPhone() != null ? request.getPhone() : request.getAccount();
        Member member = memberRepository.findByPhone(phone)
                .orElseThrow(() -> new NotFoundException("会员不存在"));

        session.setAttribute("userId", member.getMemberId());
        session.setAttribute("userName", member.getMemberName());
        session.setAttribute("userRole", "customer");
        session.setAttribute("userType", "member");

        Map<String, Object> result = new HashMap<>();
        result.put("userId", member.getMemberId());
        result.put("userName", member.getMemberName());
        result.put("userRole", "customer");
        result.put("userType", "member");
        log.info("会员登录成功: {}", member.getMemberName());
        return result;
    }

    public void requireLogin(HttpSession session) {
        if (session.getAttribute("userId") == null) {
            throw new AuthException("请先登录");
        }
    }

    public void requireRole(HttpSession session, String role) {
        requireLogin(session);
        String userRole = (String) session.getAttribute("userRole");
        if (!role.equals(userRole)) {
            throw new com.retail.store.exception.PermissionDeniedException("无权限执行此操作");
        }
    }

    public void canManageProducts(HttpSession session) {
        requireRole(session, "manager");
    }

    public void canManageInventory(HttpSession session) {
        requireLogin(session);
        String role = (String) session.getAttribute("userRole");
        if (!"manager".equals(role) && !"cashier".equals(role)) {
            throw new com.retail.store.exception.PermissionDeniedException("无权限执行此操作");
        }
    }

    public void canCreateOrder(HttpSession session) {
        requireLogin(session);
    }
}
