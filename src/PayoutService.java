import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.UUID;

@Service
public class PayoutService {

    private final JdbcTemplate jdbcTemplate;

    public PayoutService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional
    public Payout createPayout(PayoutRequest request, String idempotencyKey, String clientId) {
        String insertSql = """
            INSERT INTO payouts (client_id, idempotency_key, amount_cents, currency, recipient_id, status)
            VALUES (?, ?, ?, ?, ?, 'PENDING')
            RETURNING id, client_id, idempotency_key, amount_cents, currency, recipient_id, status, created_at
        """;

        try {

            return jdbcTemplate.queryForObject(insertSql, 
                new PayoutRowMapper(),
                clientId, idempotencyKey, request.getAmount(), request.getCurrency(), request.getRecipientId()
            );

        } catch (DuplicateKeyException e) {
            String selectSql = """
                SELECT id, client_id, idempotency_key, amount_cents, currency, recipient_id, status, created_at
                FROM payouts
                WHERE client_id = ? AND idempotency_key = ?
            """;
            
            return jdbcTemplate.queryForObject(selectSql, 
                new PayoutRowMapper(), 
                clientId, idempotencyKey
            );
        }
    }
}