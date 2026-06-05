using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Repositories;

public class EmploymentContractRepository : IEmploymentContractRepository
{
    private readonly SRJDbContext _context;

    public EmploymentContractRepository(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<int> CreateAsync(DEmploymentContract contract)
    {
        var ec = new EmploymentContract
        {
            StaffMemberId = contract.StaffMemberId,
            InstitutionId = contract.InstitutionId,
            SchoolYearId = contract.SchoolYearId,
            JobPositionId = contract.JobPositionId,
            AreaId = contract.AreaId,
            StartDate = contract.StartDate,
            EndDate = contract.EndDate,
            Salary = contract.Salary
        };
        _context.EmploymentContracts.Add(ec);
        await _context.SaveChangesAsync();
        return ec.Id;
    }

    public async Task UpdateAsync(DEmploymentContract contract)
    {
        var ec = await _context.EmploymentContracts.FindAsync(contract.Id);
        if (ec == null) return;
        ec.InstitutionId = contract.InstitutionId;
        ec.SchoolYearId = contract.SchoolYearId;
        ec.JobPositionId = contract.JobPositionId;
        ec.AreaId = contract.AreaId;
        ec.StartDate = contract.StartDate;
        ec.EndDate = contract.EndDate;
        ec.Salary = contract.Salary;
        await _context.SaveChangesAsync();
    }

    public async Task<DEmploymentContract?> GetByIdAsync(int id)
    {
        var ec = await _context.EmploymentContracts.FirstOrDefaultAsync(e => e.Id == id);
        if (ec == null) return null;
        return DEmploymentContract.Reconstitute(
            ec.Id, ec.StaffMemberId, ec.InstitutionId, ec.SchoolYearId,
            ec.JobPositionId, ec.AreaId, ec.StartDate, ec.EndDate, ec.Salary);
    }

    public async Task<bool> ExistsAsync(int id)
        => await _context.EmploymentContracts.AnyAsync(e => e.Id == id);

    public async Task<bool> TryDeleteAsync(int id)
    {
        var ec = await _context.EmploymentContracts.FindAsync(id);
        if (ec == null) return false;
        try
        {
            _context.EmploymentContracts.Remove(ec);
            await _context.SaveChangesAsync();
            return true;
        }
        catch (DbUpdateException)
        {
            _context.Entry(ec).State = EntityState.Unchanged;
            return false;
        }
    }
}
