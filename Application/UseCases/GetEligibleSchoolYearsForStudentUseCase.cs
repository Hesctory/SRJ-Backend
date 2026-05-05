using Microsoft.EntityFrameworkCore;
using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;
using SRJBackend.Infrastructure.Models;

namespace SRJBackend.Application.UseCases;

public class GetEligibleSchoolYearsForStudentUseCase
{
    private readonly IStudentRepository _studentRepository;
    private readonly SRJDbContext _context;

    public GetEligibleSchoolYearsForStudentUseCase(
        IStudentRepository studentRepository,
        SRJDbContext context)
    {
        _studentRepository = studentRepository;
        _context = context;
    }

    public async Task<List<EligibleSchoolYearDTO>> ExecuteAsync(int studentId)
    {
        if (!await _studentRepository.ExistsByEducationalPersonIdAsync(studentId))
            throw new DomainException("STUDENT_NOT_FOUND", "El estudiante no existe.");

        var blockedStatuses = new[] { StudentStateNames.Blocked.ToLower(), StudentStateNames.Expelled.ToLower(), StudentStateNames.Withdrawn.ToLower() };

        var eligibleYears = await _context.SchoolYears
            .Where(y => y.IsActive == true)
            .Select(y => new EligibleSchoolYearDTO
            {
                Id = y.Id,
                Name = y.Year.ToString(),
                GradeOfferingsAvailable = _context.GradeOfferings.Any(go => go.SchoolYearId == y.Id)
            })
            .ToListAsync();

        foreach (var year in eligibleYears)
        {
            var hasEnrollment = await _context.Enrollments
                .AnyAsync(e => e.StudentId == studentId
                         && e.GradeOfferingShiftSection.GradeOfferingShift.GradeOffering.SchoolYearId == year.Id);

            var hasBlockedStatus = await _context.StudentStatesByYears
                .AnyAsync(s => s.StudentId == studentId
                         && s.SchoolYearId == year.Id
                         && s.Status != null
                         && blockedStatuses.Contains(s.Status.Name.ToLower()));

            if (hasEnrollment || hasBlockedStatus)
                eligibleYears.RemoveAll(y => y.Id == year.Id);
        }

        return eligibleYears;
    }
}