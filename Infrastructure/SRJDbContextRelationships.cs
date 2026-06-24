using Microsoft.EntityFrameworkCore;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Models;

// Hand-written companion to the scaffolded SRJDbContext. It lives OUTSIDE
// Infrastructure/Models/ on purpose so `dotnet ef dbcontext scaffold --force`
// never overwrites it, and it hooks the model through the generated
// OnModelCreatingPartial extension point instead of editing generated files.
public partial class SRJDbContext
{
    partial void OnModelCreatingPartial(ModelBuilder modelBuilder)
    {
        // The DB only has a PARTIAL unique index on enrollment_debts.enrollment_id
        // (uq_debt_enrollment_fee ... WHERE charge_type_id = 2): at most one ENROLLMENT
        // (matrícula) debt per enrollment — NOT a 1:1. The EF scaffolder ignores the
        // WHERE predicate and models Enrollment<->EnrollmentDebt as one-to-one, which
        // makes adding more than one debt per enrollment (admission + enrollment, monthly
        // tuition) sever the relationship. Re-map it to the true one-to-many.
        modelBuilder.Entity<Enrollment>().Ignore(e => e.EnrollmentDebt);

        modelBuilder.Entity<EnrollmentDebt>()
            .HasOne(d => d.Enrollment)
            .WithMany()
            .HasForeignKey(d => d.EnrollmentId)
            .OnDelete(DeleteBehavior.ClientSetNull)
            .HasConstraintName("student_debts_enrollment_id_fkey");
    }
}
