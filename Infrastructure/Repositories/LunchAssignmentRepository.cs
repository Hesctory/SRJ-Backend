using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class LunchAssignmentRepository : ILunchAssignmentRepository
{
    private readonly SRJDbContext _context;

    public LunchAssignmentRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<int> CreateAsync(DLunchAssignment assignment)
    {
        var efAssignment = new LunchAssignment
        {
            PersonId = assignment.PersonId,
            EnrollmentId = assignment.EnrollmentId,
            LunchId = assignment.LunchId,
            AssignedDate = assignment.AssignedDate,
            UnitPrice = assignment.UnitPrice,
            AssignedById = assignment.AssignedById,
            HasDebt = assignment.HasDebt,
            IsSettled = assignment.IsSettled,
            DebtPaidAmount = assignment.DebtPaidAmount,
            DebtPaidDate = assignment.DebtPaidDate
        };
        _context.LunchAssignments.Add(efAssignment);
        await _context.SaveChangesAsync();
        return efAssignment.Id;
    }

    public async Task<DLunchAssignment?> GetByIdAsync(int id)
    {
        var row = await _context.LunchAssignments
            .AsNoTracking()
            .Include(a => a.Lunch)
            .FirstOrDefaultAsync(a => a.Id == id);

        return row == null ? null : Reconstitute(row);
    }

    public async Task<List<DLunchAssignment>> GetUnpaidByPersonAsync(int personId)
    {
        var rows = await _context.LunchAssignments
            .AsNoTracking()
            .Include(a => a.Lunch)
            .Where(a => a.PersonId == personId && a.HasDebt && !a.IsSettled)
            .OrderBy(a => a.AssignedDate)
            .ThenBy(a => a.Id)
            .ToListAsync();

        return rows.Select(Reconstitute).ToList();
    }

    public async Task UpdateDebtPaymentsAsync(IReadOnlyList<DLunchAssignment> assignments)
    {
        foreach (var assignment in assignments)
        {
            var row = await _context.LunchAssignments.FindAsync(assignment.Id)
                ?? throw new KeyNotFoundException($"Asignación de almuerzo {assignment.Id} no encontrada.");

            row.DebtPaidAmount = assignment.DebtPaidAmount;
            row.DebtPaidDate = assignment.DebtPaidDate;
            row.IsSettled = assignment.IsSettled;
        }

        await _context.SaveChangesAsync();
    }

    public async Task<bool> DeleteAsync(int id)
    {
        var row = await _context.LunchAssignments.FindAsync(id);
        if (row == null) return false;

        _context.LunchAssignments.Remove(row);
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> PersonExistsAsync(int personId)
        => await _context.People.AnyAsync(p => p.Id == personId);

    public async Task<bool> EnrollmentBelongsToPersonAsync(int enrollmentId, int personId)
        => await _context.Enrollments.AnyAsync(e => e.Id == enrollmentId && e.StudentId == personId);

    private static DLunchAssignment Reconstitute(LunchAssignment row)
        => DLunchAssignment.Reconstitute(
            row.Id, row.PersonId, row.EnrollmentId, row.LunchId, row.Lunch.LunchName,
            row.AssignedDate, row.UnitPrice, row.AssignedById,
            row.HasDebt, row.IsSettled, row.DebtPaidAmount, row.DebtPaidDate);
}
