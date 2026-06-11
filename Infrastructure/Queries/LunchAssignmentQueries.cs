using System.Linq.Expressions;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Infrastructure.Queries;

public class LunchAssignmentQueries : ILunchAssignmentQueries
{
    private readonly SRJDbContext _context;

    public LunchAssignmentQueries(SRJDbContext context)
    {
        _context = context;
    }

    public async Task<(List<LunchAssignmentDTO> Items, int Total)> GetPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.LunchAssignments.AsNoTracking();

        if (filters != null)
        {
            if (filters.TryGetValue("personId", out var personEl) && personEl.TryGetInt32(out var personId))
                query = query.Where(a => a.PersonId == personId);

            if (filters.TryGetValue("enrollmentId", out var enrollmentEl) && enrollmentEl.TryGetInt32(out var enrollmentId))
                query = query.Where(a => a.EnrollmentId == enrollmentId);

            if (filters.TryGetValue("lunchId", out var lunchEl) && lunchEl.TryGetInt32(out var lunchId))
                query = query.Where(a => a.LunchId == lunchId);

            if (filters.TryGetValue("assignedDate", out var dateEl)
                && DateOnly.TryParse(dateEl.GetString(), out var assignedDate))
                query = query.Where(a => a.AssignedDate == assignedDate);

            if (filters.TryGetValue("assignedDateFrom", out var fromEl)
                && DateOnly.TryParse(fromEl.GetString(), out var dateFrom))
                query = query.Where(a => a.AssignedDate >= dateFrom);

            if (filters.TryGetValue("assignedDateTo", out var toEl)
                && DateOnly.TryParse(toEl.GetString(), out var dateTo))
                query = query.Where(a => a.AssignedDate <= dateTo);

            if (filters.TryGetValue("hasDebt", out var hasDebtEl)
                && hasDebtEl.ValueKind is JsonValueKind.True or JsonValueKind.False)
                query = query.Where(a => a.HasDebt == hasDebtEl.GetBoolean());

            if (filters.TryGetValue("isSettled", out var isSettledEl)
                && isSettledEl.ValueKind is JsonValueKind.True or JsonValueKind.False)
                query = query.Where(a => a.IsSettled == isSettledEl.GetBoolean());

            if (filters.TryGetValue("id", out var idEl) && idEl.ValueKind == JsonValueKind.Array)
            {
                var ids = idEl.EnumerateArray()
                    .Where(e => e.TryGetInt32(out _))
                    .Select(e => e.GetInt32())
                    .ToList();
                query = query.Where(a => ids.Contains(a.Id));
            }
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderBy(a => a.AssignedDate)
            .ThenBy(a => a.Id)
            .Skip(skip)
            .Take(take)
            .Select(ToDtoProjection)
            .ToListAsync();

        return (items, total);
    }

    public async Task<LunchAssignmentDTO?> GetByIdAsync(int id)
    {
        return await _context.LunchAssignments
            .AsNoTracking()
            .Where(a => a.Id == id)
            .Select(ToDtoProjection)
            .FirstOrDefaultAsync();
    }

    public async Task<(List<LunchDebtSummaryDTO> Items, int Total)> GetDebtSummariesPagedAsync(int skip, int take, Dictionary<string, JsonElement>? filters = null)
    {
        var query = _context.LunchAssignments
            .AsNoTracking()
            .Where(a => a.HasDebt && !a.IsSettled);

        if (filters != null)
        {
            if (filters.TryGetValue("personId", out var personEl) && personEl.TryGetInt32(out var personId))
                query = query.Where(a => a.PersonId == personId);

            if (filters.TryGetValue("personType", out var typeEl) && typeEl.GetString() is string personType)
            {
                if (personType == "student")
                    query = query.Where(a => a.Person.Student != null);
                else if (personType == "staff")
                    query = query.Where(a => a.Person.StaffMember != null);
            }

            if (filters.TryGetValue("q", out var qEl) && qEl.GetString() is string q)
            {
                var term = q.ToLower();
                query = query.Where(a =>
                    (a.Person.Names + " " + a.Person.PaternalLastname + " " + a.Person.MaternalLastname)
                    .ToLower().Contains(term));
            }
        }

        var grouped = query.GroupBy(a => new
        {
            a.PersonId,
            a.Person.Names,
            a.Person.PaternalLastname,
            a.Person.MaternalLastname,
            IsStudent = a.Person.Student != null,
            IsStaff = a.Person.StaffMember != null
        });

        var total = await grouped.CountAsync();
        var items = await grouped
            .OrderBy(g => g.Key.PaternalLastname)
            .ThenBy(g => g.Key.MaternalLastname)
            .ThenBy(g => g.Key.Names)
            .Skip(skip)
            .Take(take)
            .Select(g => new LunchDebtSummaryDTO
            {
                id = g.Key.PersonId,
                PersonFullName = g.Key.Names + " " + g.Key.PaternalLastname + " " + g.Key.MaternalLastname,
                PersonType = g.Key.IsStudent ? "student" : g.Key.IsStaff ? "staff" : "other",
                UnpaidCount = g.Count(),
                TotalDebt = g.Sum(a => a.UnitPrice - (a.DebtPaidAmount ?? 0m)),
                OldestUnpaidDate = g.Min(a => a.AssignedDate)
            })
            .ToListAsync();

        return (items, total);
    }

    private static readonly Expression<Func<LunchAssignment, LunchAssignmentDTO>> ToDtoProjection = a => new LunchAssignmentDTO
    {
        id = a.Id,
        PersonId = a.PersonId,
        PersonFullName = a.Person.Names + " " + a.Person.PaternalLastname + " " + a.Person.MaternalLastname,
        EnrollmentId = a.EnrollmentId,
        LunchId = a.LunchId,
        LunchName = a.Lunch.LunchName,
        AssignedDate = a.AssignedDate,
        UnitPrice = a.UnitPrice,
        HasDebt = a.HasDebt,
        IsSettled = a.IsSettled,
        DebtPaidAmount = a.DebtPaidAmount,
        DebtPaidDate = a.DebtPaidDate,
        BalanceDue = a.HasDebt && !a.IsSettled ? a.UnitPrice - (a.DebtPaidAmount ?? 0m) : 0m,
        AssignedById = a.AssignedById
    };
}
